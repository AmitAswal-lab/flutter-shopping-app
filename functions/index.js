"use strict";

const {randomUUID} = require("node:crypto");
const {
  getFirestore,
  FieldValue,
  Timestamp,
} = require("firebase-admin/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getMessaging} = require("firebase-admin/messaging");
const {logger} = require("firebase-functions");
const {defineSecret} = require("firebase-functions/params");
const {onCall, onRequest, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const Razorpay = require("razorpay");

const {
  CheckoutInputError,
  parseCheckoutRequest,
} = require("./order_utils");
const {
  PaymentInputError,
  parsePaymentRequest,
  parseRazorpayOrderRequest,
  parseRazorpayVerificationRequest,
  parseStoredOrderItems,
} = require("./payment_utils");
const {verifyRazorpaySignature} = require("./razorpay_utils");
const {
  RazorpayWebhookPayloadError,
  parseRazorpayWebhookEvent,
  verifyRazorpayWebhookSignature,
  webhookEventId,
} = require("./razorpay_webhook_utils");
const {reconcileRazorpayWebhook} = require("./webhook_reconciliation");
const {
  OrderFulfillmentInputError,
  nextLifecycleTransition,
  parseOrderFulfillmentRequest,
} = require("./order_lifecycle_utils");
const {reserveCheckout} = require("./checkout_transaction");
const {
  OrderCancellationInputError,
  parseOrderCancellationRequest,
} = require("./order_cancellation_utils");
const {
  claimOrderCancellation,
  finalizeOrderCancellation,
  releaseFailedCancellation,
} = require("./order_cancellation_transaction");
const {
  createOrRecoverRefund,
} = require("./razorpay_refund_service");
const {applyRefundStatus} = require("./refund_tracking");
const {
  ReviewInputError,
  parseReviewDeleteRequest,
  parseReviewRequest,
} = require("./review_utils");
const {removeReview, upsertReview} = require("./review_transaction");
const {
  deleteCustomerFirestoreData,
  isRecentAuthentication,
} = require("./account_deletion");
const {
  AdminProductInputError,
  parseAdminProductRequest,
} = require("./admin_product_utils");
const {
  isInvalidRegistrationError,
  notificationItemLabel,
  notificationForRefundStatus,
  notificationForStatus,
} = require("./notification_utils");

initializeApp();

const db = getFirestore();
const PAYMENT_RESERVATION_MINUTES = 15;
const PENDING_PAYMENT = "pendingPayment";
const razorpayKeyId = defineSecret("RAZORPAY_KEY_ID");
const razorpayKeySecret = defineSecret("RAZORPAY_KEY_SECRET");
const razorpayWebhookSecret = defineSecret("RAZORPAY_WEBHOOK_SECRET");

exports.upsertCatalogProduct = onCall(
  {region: "us-central1", invoker: "public"},
  async (request) => {
    await requireAdmin(request.auth);

    let product;
    try {
      product = parseAdminProductRequest(request.data);
    } catch (error) {
      if (error instanceof AdminProductInputError) {
        throw new HttpsError("invalid-argument", error.message);
      }
      throw error;
    }

    const productRef = db.collection("products").doc(product.productId);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(productRef);
      const existing = snapshot.data();
      const imageAsset = existing?.imageAsset ||
        "assets/products/catalog_placeholder.png";

      transaction.set(productRef, {
        brand: product.brand,
        category: product.category,
        createdAt: existing?.createdAt || FieldValue.serverTimestamp(),
        createdBy: existing?.createdBy || request.auth.uid,
        description: product.description,
        imageAsset,
        imageStoragePath: product.imageStoragePath,
        imageUrl: product.imageUrl,
        isActive: product.isActive,
        listPriceCents: product.listPriceCents,
        name: product.name,
        priceCents: product.priceCents,
        rating: existing?.rating || 0,
        reviewCount: existing?.reviewCount || 0,
        sortOrder: product.sortOrder,
        stockCount: product.stockCount,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: request.auth.uid,
      });
    });

    return {productId: product.productId};
  },
);

exports.sendOrderStatusNotification = onDocumentUpdated(
  {
    document: "users/{userId}/orders/{orderId}",
    region: "us-central1",
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const {orderId, userId} = event.params;
    const statusChanged = before.status !== after.status;
    const refundStatusChanged = before.refundStatus !== after.refundStatus;
    const itemLabel = notificationItemLabel(after.items);
    const notification = statusChanged ?
      notificationForStatus(after.status, itemLabel) :
      refundStatusChanged ?
        notificationForRefundStatus(after.refundStatus, itemLabel) : null;
    if (notification == null) return;
    const notificationStatus = statusChanged ?
      after.status : after.refundStatus;
    const notificationType = statusChanged ? "orderStatus" : "refundStatus";

    const eventId = event.id.replaceAll("/", "_");
    const deliveryRef = db
      .collection("users")
      .doc(userId)
      .collection("notificationDeliveries")
      .doc(eventId);
    const claimed = await db.runTransaction(async (transaction) => {
      const delivery = await transaction.get(deliveryRef);
      if (delivery.exists) return false;

      transaction.create(deliveryRef, {
        createdAt: FieldValue.serverTimestamp(),
        orderId,
        status: notificationStatus,
        state: "processing",
      });
      return true;
    });
    if (!claimed) return;

    try {
      const registrations = await db
        .collection("users")
        .doc(userId)
        .collection("deviceRegistrations")
        .get();
      const tokenDocuments = registrations.docs.filter((document) => {
        const token = document.data().token;
        return typeof token === "string" && token.length > 0;
      });

      if (tokenDocuments.length === 0) {
        await deliveryRef.update({
          completedAt: FieldValue.serverTimestamp(),
          state: "noDevices",
        });
        return;
      }

      let successCount = 0;
      let failureCount = 0;
      const invalidRegistrations = [];
      for (let offset = 0; offset < tokenDocuments.length; offset += 500) {
        const chunk = tokenDocuments.slice(offset, offset + 500);
        const response = await getMessaging().sendEachForMulticast({
          android: {priority: "high"},
          apns: {payload: {aps: {sound: "default"}}},
          data: {
            orderId,
            status: notificationStatus,
            type: notificationType,
          },
          notification,
          tokens: chunk.map((document) => document.data().token),
        });

        successCount += response.successCount;
        failureCount += response.failureCount;
        response.responses.forEach((result, index) => {
          if (!result.success && isInvalidRegistrationError(result.error)) {
            invalidRegistrations.push(chunk[index].ref);
          }
        });
      }

      if (invalidRegistrations.length > 0) {
        const batch = db.batch();
        invalidRegistrations.forEach((registration) =>
          batch.delete(registration),
        );
        await batch.commit();
      }

      await deliveryRef.update({
        completedAt: FieldValue.serverTimestamp(),
        failureCount,
        state: "sent",
        successCount,
      });
    } catch (error) {
      await deliveryRef.delete();
      logger.error("Could not send order status notification", {
        error,
        orderId,
        userId,
      });
      throw error;
    }
  },
);

exports.submitProductReview = onCall(
  {region: "us-central1", invoker: "public"},
  async (request) => {
    requireVerifiedCustomer(request.auth);

    let review;
    try {
      review = parseReviewRequest(request.data);
    } catch (error) {
      if (error instanceof ReviewInputError) {
        throw new HttpsError("invalid-argument", error.message);
      }
      throw error;
    }

    return upsertReview({
      authEmail: request.auth.token.email,
      comment: review.comment,
      db,
      productId: review.productId,
      rating: review.rating,
      userId: request.auth.uid,
    });
  },
);

async function requireAdmin(auth) {
  if (!auth) {
    throw new HttpsError(
      "unauthenticated",
      "You must be signed in to manage the catalog.",
    );
  }

  const admin = await db.collection("admins").doc(auth.uid).get();
  if (!admin.exists) {
    throw new HttpsError(
      "permission-denied",
      "This account is not an administrator.",
    );
  }
}

function requireVerifiedCustomer(auth) {
  if (!auth) {
    throw new HttpsError(
      "unauthenticated",
      "You must be signed in to continue.",
    );
  }

  if (auth.token.email_verified !== true) {
    throw new HttpsError(
      "permission-denied",
      "Verify your email address before continuing.",
    );
  }
}

exports.deleteAccount = onCall(
  {region: "us-central1", invoker: "public"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in to delete your account.",
      );
    }

    const userId = request.auth.uid;
    if (!isRecentAuthentication(request.auth.token.auth_time)) {
      throw new HttpsError(
        "failed-precondition",
        "Sign in again before deleting your account.",
      );
    }

    try {
      const cleanup = await deleteCustomerFirestoreData({db, userId});
      await getAuth().deleteUser(userId);
      logger.info("Deleted customer account", {userId, ...cleanup});
      return {deleted: true};
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      logger.error("Could not delete customer account", {error, userId});
      throw new HttpsError(
        "internal",
        "Could not delete the account. Please try again.",
      );
    }
  },
);

exports.deleteProductReview = onCall(
  {region: "us-central1", invoker: "public"},
  async (request) => {
    requireVerifiedCustomer(request.auth);

    let review;
    try {
      review = parseReviewDeleteRequest(request.data);
    } catch (error) {
      if (error instanceof ReviewInputError) {
        throw new HttpsError("invalid-argument", error.message);
      }
      throw error;
    }

    return removeReview({
      db,
      productId: review.productId,
      userId: request.auth.uid,
    });
  },
);

exports.placeOrder = onCall(
  {region: "us-central1", invoker: "public"},
  async (request) => {
    requireVerifiedCustomer(request.auth);

    let checkout;
    try {
      checkout = parseCheckoutRequest(request.data);
    } catch (error) {
      if (error instanceof CheckoutInputError) {
        throw new HttpsError("invalid-argument", error.message);
      }
      throw error;
    }

    const userId = request.auth.uid;
    try {
      return await reserveCheckout({
        authEmail: request.auth.token.email,
        checkout,
        db,
        paymentReservationMinutes: PAYMENT_RESERVATION_MINUTES,
        userId,
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;

      logger.error("placeOrder transaction failed", {
        userId,
        checkoutId: checkout.checkoutId,
        error,
      });
      throw new HttpsError("internal", "Could not place the order. Try again.");
    }
  },
);

exports.cancelOrder = onCall(
  {
    region: "us-central1",
    invoker: "public",
    secrets: [razorpayKeyId, razorpayKeySecret],
  },
  async (request) => {
    requireVerifiedCustomer(request.auth);

    let input;
    try {
      input = parseOrderCancellationRequest(request.data);
    } catch (error) {
      if (error instanceof OrderCancellationInputError) {
        throw new HttpsError("invalid-argument", error.message);
      }
      throw error;
    }

    const orderRef = db
      .collection("users")
      .doc(request.auth.uid)
      .collection("orders")
      .doc(input.orderId);

    const processingToken = randomUUID();
    let claim;
    try {
      claim = await claimOrderCancellation({
        db,
        orderRef,
        processingToken,
        userId: request.auth.uid,
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;

      logger.error("Order cancellation failed", {
        error,
        orderId: input.orderId,
        userId: request.auth.uid,
      });
      throw new HttpsError(
        "internal",
        "Could not cancel the order. Try again.",
      );
    }

    if (claim.state === "completed") return claim.result;

    if (!claim.requiresRefund) {
      return finalizeOrderCancellation({
        db,
        orderRef,
        processingToken: claim.processingToken,
        userId: request.auth.uid,
      });
    }

    try {
      const razorpay = createRazorpayClient();
      const refund = await createOrRecoverRefund({
        amount: claim.amount,
        orderId: claim.orderId,
        paymentId: claim.paymentId,
        processingToken: claim.processingToken,
        razorpay,
        userId: request.auth.uid,
      });
      if (refund.status === "failed") {
        await releaseFailedCancellation({
          errorMessage: "Razorpay rejected the refund.",
          orderRef,
          processingToken: claim.processingToken,
        });
        throw new HttpsError(
          "failed-precondition",
          "Razorpay could not start the refund. Try again.",
        );
      }

      return await finalizeOrderCancellation({
        db,
        orderRef,
        processingToken: claim.processingToken,
        refund,
        userId: request.auth.uid,
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;

      if (isNonRetryableRazorpayError(error)) {
        await releaseFailedCancellation({
          errorMessage: razorpayErrorMessage(error),
          orderRef,
          processingToken: claim.processingToken,
        });
      }
      logger.error("Razorpay refund creation failed", {
        error,
        orderId: input.orderId,
        paymentId: claim.paymentId,
        userId: request.auth.uid,
      });
      throw new HttpsError(
        "unavailable",
        "Could not start the refund. Try again shortly.",
      );
    }
  },
);

exports.refreshOrderRefund = onCall(
  {
    region: "us-central1",
    invoker: "public",
    secrets: [razorpayKeyId, razorpayKeySecret],
  },
  async (request) => {
    requireVerifiedCustomer(request.auth);

    let input;
    try {
      input = parseOrderCancellationRequest(request.data);
    } catch (error) {
      if (error instanceof OrderCancellationInputError) {
        throw new HttpsError("invalid-argument", error.message);
      }
      throw error;
    }

    const orderRef = db
      .collection("users")
      .doc(request.auth.uid)
      .collection("orders")
      .doc(input.orderId);
    const orderSnapshot = await orderRef.get();
    if (!orderSnapshot.exists) {
      throw new HttpsError("not-found", "Order was not found.");
    }

    const order = orderSnapshot.data();
    if (order.status !== "cancelled" || !order.refundId) {
      throw new HttpsError(
        "failed-precondition",
        "This order does not have a refund to refresh.",
      );
    }

    try {
      const gatewayRefund = await createRazorpayClient()
        .refunds.fetch(order.refundId);
      const refund = await applyRefundStatus({db, gatewayRefund});
      return {
        orderId: input.orderId,
        refundId: refund.id,
        refundStatus: refund.status,
      };
    } catch (error) {
      logger.error("Could not refresh Razorpay refund", {
        error,
        orderId: input.orderId,
        refundId: order.refundId,
        userId: request.auth.uid,
      });
      throw new HttpsError(
        "unavailable",
        "Could not refresh the refund. Try again.",
      );
    }
  },
);

exports.resolvePayment = onCall(
  {region: "us-central1", invoker: "public"},
  async (request) => {
    requireVerifiedCustomer(request.auth);

    let payment;
    try {
      payment = parsePaymentRequest(request.data);
    } catch (error) {
      if (error instanceof PaymentInputError) {
        throw new HttpsError("invalid-argument", error.message);
      }
      throw error;
    }

    const orderRef = db
      .collection("users")
      .doc(request.auth.uid)
      .collection("orders")
      .doc(payment.orderId);

    return resolvePendingOrder(orderRef, payment.outcome);
  },
);

exports.createRazorpayOrder = onCall(
  {
    region: "us-central1",
    invoker: "public",
    secrets: [razorpayKeyId, razorpayKeySecret],
  },
  async (request) => {
    requireVerifiedCustomer(request.auth);

    let payment;
    try {
      payment = parseRazorpayOrderRequest(request.data);
    } catch (error) {
      if (error instanceof PaymentInputError) {
        throw new HttpsError("invalid-argument", error.message);
      }
      throw error;
    }

    const userId = request.auth.uid;
    const orderRef = db
      .collection("users")
      .doc(userId)
      .collection("orders")
      .doc(payment.orderId);
    const creationToken = randomUUID();
    const claim = await db.runTransaction(async (transaction) => {
      const orderSnapshot = await transaction.get(orderRef);
      if (!orderSnapshot.exists) {
        throw new HttpsError("not-found", "Order was not found.");
      }

      const order = orderSnapshot.data();
      ensurePendingOrder(order);
      ensureReservationActive(order);
      if (order.razorpayOrderId) {
        return {order, shouldCreate: false};
      }
      if (order.razorpayOrderCreationToken) {
        throw new HttpsError(
          "aborted",
          "Razorpay Checkout is already being prepared. Try again.",
        );
      }

      transaction.update(orderRef, {
        razorpayOrderCreationStartedAt: FieldValue.serverTimestamp(),
        razorpayOrderCreationToken: creationToken,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return {order, shouldCreate: true};
    });

    if (!claim.shouldCreate) {
      return razorpayCheckoutResult(
        orderRef.id,
        claim.order,
        razorpayKeyId.value(),
        request.auth.token.email,
      );
    }

    let gatewayOrder;
    try {
      const razorpay = new Razorpay({
        key_id: razorpayKeyId.value(),
        key_secret: razorpayKeySecret.value(),
      });
      gatewayOrder = await razorpay.orders.create({
        amount: claim.order.totalPriceCents,
        currency: "INR",
        receipt: orderRef.id,
        notes: {
          appOrderId: orderRef.id,
          userId,
        },
      });
    } catch (error) {
      await releaseRazorpayOrderClaim(orderRef, creationToken);
      logger.error("Razorpay order creation failed", {
        userId,
        orderId: orderRef.id,
        error,
      });
      throw new HttpsError(
        "unavailable",
        "Could not start Razorpay Checkout. Try again.",
      );
    }

    const currentOrder = await db.runTransaction(async (transaction) => {
      const currentSnapshot = await transaction.get(orderRef);
      if (!currentSnapshot.exists) {
        throw new HttpsError("not-found", "Order was not found.");
      }

      const current = currentSnapshot.data();
      ensurePendingOrder(current);
      ensureReservationActive(current);
      if (current.razorpayOrderCreationToken !== creationToken) {
        throw new HttpsError(
          "aborted",
          "Razorpay Checkout preparation was interrupted. Try again.",
        );
      }

      transaction.update(orderRef, {
        paymentProvider: "razorpay",
        razorpayOrderId: gatewayOrder.id,
        razorpayOrderCreationStartedAt: FieldValue.delete(),
        razorpayOrderCreationToken: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return {...current, razorpayOrderId: gatewayOrder.id};
    });

    return razorpayCheckoutResult(
      orderRef.id,
      currentOrder,
      razorpayKeyId.value(),
      request.auth.token.email,
    );
  },
);

exports.verifyRazorpayPayment = onCall(
  {
    region: "us-central1",
    invoker: "public",
    secrets: [razorpayKeySecret],
  },
  async (request) => {
    requireVerifiedCustomer(request.auth);

    let payment;
    try {
      payment = parseRazorpayVerificationRequest(request.data);
    } catch (error) {
      if (error instanceof PaymentInputError) {
        throw new HttpsError("invalid-argument", error.message);
      }
      throw error;
    }

    const orderRef = db
      .collection("users")
      .doc(request.auth.uid)
      .collection("orders")
      .doc(payment.orderId);
    const orderSnapshot = await orderRef.get();
    if (!orderSnapshot.exists) {
      throw new HttpsError("not-found", "Order was not found.");
    }

    const order = orderSnapshot.data();
    if (order.razorpayOrderId !== payment.razorpayOrderId) {
      throw new HttpsError(
        "failed-precondition",
        "Razorpay order does not match this checkout.",
      );
    }
    if (
      !verifyRazorpaySignature({
        razorpayOrderId: order.razorpayOrderId,
        razorpayPaymentId: payment.razorpayPaymentId,
        razorpaySignature: payment.razorpaySignature,
        secret: razorpayKeySecret.value(),
      })
    ) {
      throw new HttpsError(
        "permission-denied",
        "Payment signature verification failed.",
      );
    }

    return db.runTransaction(async (transaction) => {
      const currentSnapshot = await transaction.get(orderRef);
      if (!currentSnapshot.exists) {
        throw new HttpsError("not-found", "Order was not found.");
      }

      const current = currentSnapshot.data();
      if (current.status === "paid") {
        return paymentResult(orderRef.id, current);
      }
      ensurePendingOrder(current);
      if (current.razorpayOrderId !== payment.razorpayOrderId) {
        throw new HttpsError(
          "failed-precondition",
          "Razorpay order does not match this checkout.",
        );
      }

      transaction.update(orderRef, {
        paidAt: FieldValue.serverTimestamp(),
        razorpayPaymentId: payment.razorpayPaymentId,
        status: "paid",
        updatedAt: FieldValue.serverTimestamp(),
      });
      return paymentResult(orderRef.id, {...current, status: "paid"});
    });
  },
);

exports.razorpayWebhook = onRequest(
  {
    region: "us-central1",
    invoker: "public",
    secrets: [razorpayKeyId, razorpayKeySecret, razorpayWebhookSecret],
  },
  async (request, response) => {
    if (request.method !== "POST") {
      response.set("Allow", "POST");
      response.status(405).json({error: "Method not allowed."});
      return;
    }

    const rawBody = request.rawBody;
    const signature = request.get("x-razorpay-signature");
    if (!verifyRazorpayWebhookSignature({
      payload: rawBody,
      razorpaySignature: signature,
      secret: razorpayWebhookSecret.value(),
    })) {
      logger.warn("Rejected Razorpay webhook with an invalid signature.");
      response.status(401).json({error: "Invalid webhook signature."});
      return;
    }

    let event;
    try {
      event = parseRazorpayWebhookEvent(request.body);
    } catch (error) {
      if (error instanceof RazorpayWebhookPayloadError) {
        logger.warn("Ignored malformed Razorpay webhook.", {
          error: error.message,
        });
        response.status(200).json({received: true, ignored: true});
        return;
      }
      throw error;
    }

    try {
      const result = await reconcileRazorpayWebhook({
        db,
        event,
        eventId: webhookEventId(rawBody),
        razorpay: createRazorpayClient(),
      });
      logger.info("Razorpay webhook reconciled.", {
        action: result.action,
        eventName: event.eventName,
      });
      response.status(200).json({received: true});
    } catch (error) {
      logger.error("Could not reconcile Razorpay webhook.", {
        error,
        eventName: event.eventName,
      });
      response.status(500).json({error: "Webhook reconciliation failed."});
    }
  },
);

exports.expirePaymentReservations = onSchedule(
  {
    region: "us-central1",
    schedule: "every 15 minutes",
    timeZone: "UTC",
  },
  async () => {
    const expiredReservations = await db
      .collectionGroup("orders")
      .where("status", "==", PENDING_PAYMENT)
      .where("reservationExpiresAt", "<=", Timestamp.now())
      .limit(50)
      .get();

    let expiredCount = 0;
    for (const order of expiredReservations.docs) {
      try {
        const result = await resolvePendingOrder(order.ref, "expired");
        if (result.status === "expired") expiredCount += 1;
      } catch (error) {
        logger.error("Could not expire payment reservation", {
          orderPath: order.ref.path,
          error,
        });
      }
    }

    logger.info("Payment reservation cleanup completed", {
      expiredCount,
      inspectedCount: expiredReservations.size,
    });
  },
);

exports.syncPendingRazorpayRefunds = onSchedule(
  {
    region: "us-central1",
    schedule: "every 15 minutes",
    secrets: [razorpayKeyId, razorpayKeySecret],
    timeZone: "UTC",
  },
  async () => {
    const pendingRefunds = await db
      .collection("refunds")
      .where("status", "==", "pending")
      .limit(50)
      .get();
    const razorpay = createRazorpayClient();
    let updatedCount = 0;

    for (const refundDocument of pendingRefunds.docs) {
      try {
        const gatewayRefund = await razorpay.refunds.fetch(refundDocument.id);
        const refund = await applyRefundStatus({db, gatewayRefund});
        if (refund.status !== "pending") updatedCount += 1;
      } catch (error) {
        logger.error("Could not synchronize Razorpay refund", {
          error,
          refundId: refundDocument.id,
        });
      }
    }

    logger.info("Razorpay refund synchronization completed", {
      inspectedCount: pendingRefunds.size,
      updatedCount,
    });
  },
);

exports.advanceOrderFulfillment = onCall(
  {region: "us-central1", invoker: "public"},
  async (request) => {
    await requireAdmin(request.auth);

    let input;
    try {
      input = parseOrderFulfillmentRequest(request.data);
    } catch (error) {
      if (error instanceof OrderFulfillmentInputError) {
        throw new HttpsError("invalid-argument", error.message);
      }
      throw error;
    }

    const orderRef = db
      .collection("users")
      .doc(input.userId)
      .collection("orders")
      .doc(input.orderId);

    return db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(orderRef);
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "Order was not found.");
      }

      const order = snapshot.data();
      if (!nextLifecycleTransition(order.status)) {
        throw new HttpsError(
          "failed-precondition",
          "This order cannot advance to the next fulfillment stage.",
        );
      }

      const transition = nextLifecycleTransition(order.status);
      const updates = {
        [transition.timestampField]: FieldValue.serverTimestamp(),
        fulfillmentUpdatedBy: request.auth.uid,
        lifecycleDemoEnabled: FieldValue.delete(),
        nextLifecycleAt: FieldValue.delete(),
        status: transition.status,
        updatedAt: FieldValue.serverTimestamp(),
      };

      transaction.update(orderRef, updates);
      return {
        orderId: input.orderId,
        status: transition.status,
        userId: input.userId,
      };
    });
  },
);

async function resolvePendingOrder(orderRef, requestedOutcome) {
  try {
    return await db.runTransaction(async (transaction) => {
      const orderSnapshot = await transaction.get(orderRef);
      if (!orderSnapshot.exists) {
        throw new HttpsError("not-found", "Order was not found.");
      }

      const order = orderSnapshot.data();
      if (order.status !== PENDING_PAYMENT) {
        return paymentResult(orderRef.id, order);
      }

      const reservationExpiresAt = order.reservationExpiresAt;
      const isExpired =
        reservationExpiresAt instanceof Timestamp &&
        reservationExpiresAt.toMillis() <= Date.now();
      const outcome = isExpired ? "expired" : requestedOutcome;

      const items = parseStoredOrderItems(order.items);
      const productRefs = items.map((item) =>
        db.collection("products").doc(item.productId),
      );
      const productSnapshots = await transaction.getAll(...productRefs);

      for (let index = 0; index < items.length; index += 1) {
        if (!productSnapshots[index].exists) {
          throw new HttpsError(
            "internal",
            "Reserved inventory could not be restored.",
          );
        }
        transaction.update(productRefs[index], {
          stockCount: FieldValue.increment(items[index].quantity),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      transaction.update(orderRef, {
        resolvedAt: FieldValue.serverTimestamp(),
        status: outcome,
        stockRestored: true,
        updatedAt: FieldValue.serverTimestamp(),
      });

      return paymentResult(orderRef.id, {...order, status: outcome});
    });
  } catch (error) {
    if (error instanceof HttpsError) throw error;

    logger.error("Payment resolution failed", {
      orderPath: orderRef.path,
      requestedOutcome,
      error,
    });
    throw new HttpsError("internal", "Could not resolve payment. Try again.");
  }
}

async function releaseRazorpayOrderClaim(orderRef, creationToken) {
  try {
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(orderRef);
      if (
        !snapshot.exists ||
        snapshot.data().razorpayOrderCreationToken !== creationToken
      ) {
        return;
      }
      transaction.update(orderRef, {
        razorpayOrderCreationStartedAt: FieldValue.delete(),
        razorpayOrderCreationToken: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
  } catch (error) {
    logger.error("Could not release Razorpay order creation claim", {error});
  }
}

function paymentResult(orderId, order) {
  return {
    orderId,
    customerName: order.customerName,
    paymentMethod: order.paymentMethod,
    status: order.status,
    totalPriceCents: order.totalPriceCents,
  };
}

function ensurePendingOrder(order) {
  if (order.status !== PENDING_PAYMENT) {
    throw new HttpsError(
      "failed-precondition",
      `Order is already ${order.status}.`,
    );
  }
  if (!Number.isInteger(order.totalPriceCents) || order.totalPriceCents <= 0) {
    throw new HttpsError("internal", "Order total is invalid.");
  }
}

function createRazorpayClient() {
  return new Razorpay({
    key_id: razorpayKeyId.value(),
    key_secret: razorpayKeySecret.value(),
  });
}

function isNonRetryableRazorpayError(error) {
  const statusCode = Number(error?.statusCode || error?.status);
  return statusCode >= 400 && statusCode < 500 && statusCode !== 429;
}

function razorpayErrorMessage(error) {
  const description = error?.error?.description || error?.description;
  return typeof description === "string" ?
    description : "Razorpay rejected the refund request.";
}

function ensureReservationActive(order) {
  const expiresAt = order.reservationExpiresAt;
  if (
    expiresAt instanceof Timestamp &&
    expiresAt.toMillis() <= Date.now()
  ) {
    throw new HttpsError(
      "deadline-exceeded",
      "The payment reservation has expired.",
    );
  }
}

function razorpayCheckoutResult(orderId, order, keyId, email) {
  return {
    amount: order.totalPriceCents,
    currency: "INR",
    customerName: order.customerName,
    email: typeof email === "string" ? email : "",
    keyId,
    orderId,
    razorpayOrderId: order.razorpayOrderId,
  };
}
