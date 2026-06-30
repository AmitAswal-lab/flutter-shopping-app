"use strict";

const {randomUUID} = require("node:crypto");
const {
  getFirestore,
  FieldValue,
  Timestamp,
} = require("firebase-admin/firestore");
const {initializeApp} = require("firebase-admin/app");
const {logger} = require("firebase-functions");
const {defineSecret} = require("firebase-functions/params");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
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
  OrderLifecycleInputError,
  nextLifecycleTransition,
  parseOrderLifecycleRequest,
} = require("./order_lifecycle_utils");

initializeApp();

const db = getFirestore();
const PAYMENT_RESERVATION_MINUTES = 15;
const DEMO_LIFECYCLE_DELAY_SECONDS = 30;
const PENDING_PAYMENT = "pendingPayment";
const razorpayKeyId = defineSecret("RAZORPAY_KEY_ID");
const razorpayKeySecret = defineSecret("RAZORPAY_KEY_SECRET");

exports.placeOrder = onCall(
  {region: "us-central1", invoker: "public"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in to place an order.",
      );
    }

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
    const userRef = db.collection("users").doc(userId);
    const orderRef = userRef.collection("orders").doc(checkout.checkoutId);
    const cartRefs = checkout.productIds.map((productId) =>
      userRef.collection("cartItems").doc(productId),
    );
    const productRefs = checkout.productIds.map((productId) =>
      db.collection("products").doc(productId),
    );

    try {
      return await db.runTransaction(async (transaction) => {
        const existingOrder = await transaction.get(orderRef);
        if (existingOrder.exists) {
          const data = existingOrder.data();
          return {
            orderId: orderRef.id,
            customerName: data.customerName,
            totalPriceCents: data.totalPriceCents,
            paymentMethod: data.paymentMethod,
            status: data.status,
            reservationExpiresAtMillis:
              data.reservationExpiresAt?.toMillis() || null,
          };
        }

        const snapshots = await transaction.getAll(
          userRef,
          ...cartRefs,
          ...productRefs,
        );
        const userSnapshot = snapshots[0];
        const cartSnapshots = snapshots.slice(1, 1 + cartRefs.length);
        const productSnapshots = snapshots.slice(1 + cartRefs.length);

        const orderItems = [];
        let totalPriceCents = 0;

        for (let index = 0; index < checkout.productIds.length; index += 1) {
          const productId = checkout.productIds[index];
          const cartSnapshot = cartSnapshots[index];
          const productSnapshot = productSnapshots[index];

          if (!cartSnapshot.exists) {
            throw new HttpsError(
              "failed-precondition",
              "Your cart changed. Review it and try again.",
            );
          }
          if (
            !productSnapshot.exists ||
            productSnapshot.data().isActive === false
          ) {
            throw new HttpsError(
              "failed-precondition",
              "A product in your cart is no longer available.",
              {productId},
            );
          }

          const quantity = cartSnapshot.data().quantity;
          const product = productSnapshot.data();
          const stockCount = product.stockCount;
          const priceCents = product.priceCents;
          const productName =
            typeof product.name === "string" ? product.name.trim() : "";

          if (!Number.isInteger(quantity) || quantity <= 0) {
            throw new HttpsError(
              "failed-precondition",
              "Your cart contains an invalid quantity.",
              {productId},
            );
          }
          if (
            !Number.isInteger(stockCount) ||
            stockCount < 0 ||
            !Number.isInteger(priceCents) ||
            priceCents < 0 ||
            !productName
          ) {
            throw new HttpsError(
              "internal",
              "A product in your cart has invalid catalog data.",
              {productId},
            );
          }
          if (stockCount < quantity) {
            throw new HttpsError(
              "failed-precondition",
              `Only ${stockCount} ${productName} available.`,
              {productId, availableStock: stockCount},
            );
          }

          orderItems.push({
            productId,
            name: productName,
            priceCents,
            quantity,
          });
          totalPriceCents += priceCents * quantity;

          transaction.update(productSnapshot.ref, {
            stockCount: stockCount - quantity,
            updatedAt: FieldValue.serverTimestamp(),
          });
          transaction.delete(cartSnapshot.ref);
        }

        const profile = userSnapshot.exists ? userSnapshot.data() : {};
        const fullName =
          typeof profile.fullName === "string" ? profile.fullName.trim() : "";
        const displayName =
          typeof profile.displayName === "string" ?
            profile.displayName.trim() :
            "";
        const email =
          typeof request.auth.token.email === "string" ?
            request.auth.token.email :
            "";
        const customerName = fullName || displayName || email || "Shopper";
        const reservationExpiresAt = Timestamp.fromMillis(
          Date.now() + PAYMENT_RESERVATION_MINUTES * 60 * 1000,
        );

        transaction.create(orderRef, {
          id: orderRef.id,
          customerName,
          deliveryAddress: checkout.deliveryAddress,
          createdAt: FieldValue.serverTimestamp(),
          items: orderItems,
          paymentMethod: checkout.paymentMethod,
          reservationExpiresAt,
          stockRestored: false,
          totalPriceCents,
          status: PENDING_PAYMENT,
          updatedAt: FieldValue.serverTimestamp(),
        });

        return {
          orderId: orderRef.id,
          customerName,
          paymentMethod: checkout.paymentMethod,
          reservationExpiresAtMillis: reservationExpiresAt.toMillis(),
          status: PENDING_PAYMENT,
          totalPriceCents,
        };
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

exports.resolvePayment = onCall(
  {region: "us-central1", invoker: "public"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in to resolve a payment.",
      );
    }

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
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in to start payment.",
      );
    }

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
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in to verify payment.",
      );
    }

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

exports.startOrderLifecycleDemo = onCall(
  {region: "us-central1", invoker: "public"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in to simulate an order lifecycle.",
      );
    }

    let input;
    try {
      input = parseOrderLifecycleRequest(request.data);
    } catch (error) {
      if (error instanceof OrderLifecycleInputError) {
        throw new HttpsError("invalid-argument", error.message);
      }
      throw error;
    }

    const orderRef = db
      .collection("users")
      .doc(request.auth.uid)
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
          "This order cannot start the delivery simulation.",
        );
      }

      const nextLifecycleAt = Timestamp.fromMillis(
        Date.now() + DEMO_LIFECYCLE_DELAY_SECONDS * 1000,
      );
      const updates = {
        lifecycleDemoEnabled: true,
        nextLifecycleAt,
        updatedAt: FieldValue.serverTimestamp(),
      };

      if (order.status === "confirmed") {
        updates.status = "paid";
        updates.paidAt = order.paidAt || order.createdAt ||
          FieldValue.serverTimestamp();
      }

      transaction.update(orderRef, updates);
      return {
        nextLifecycleAtMillis: nextLifecycleAt.toMillis(),
        status: updates.status || order.status,
      };
    });
  },
);

exports.advanceOrderLifecycleDemos = onSchedule(
  {
    region: "us-central1",
    schedule: "every 1 minutes",
    timeZone: "UTC",
  },
  async () => {
    const dueOrders = await db
      .collectionGroup("orders")
      .where("lifecycleDemoEnabled", "==", true)
      .where("nextLifecycleAt", "<=", Timestamp.now())
      .limit(50)
      .get();

    let advancedCount = 0;
    for (const order of dueOrders.docs) {
      try {
        const advanced = await advanceDemoOrder(order.ref);
        if (advanced) advancedCount += 1;
      } catch (error) {
        logger.error("Could not advance demo order lifecycle", {
          orderPath: order.ref.path,
          error,
        });
      }
    }

    logger.info("Demo order lifecycle update completed", {
      advancedCount,
      inspectedCount: dueOrders.size,
    });
  },
);

async function advanceDemoOrder(orderRef) {
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(orderRef);
    if (!snapshot.exists) return false;

    const order = snapshot.data();
    const nextLifecycleAt = order.nextLifecycleAt;
    if (
      order.lifecycleDemoEnabled !== true ||
      !(nextLifecycleAt instanceof Timestamp) ||
      nextLifecycleAt.toMillis() > Date.now()
    ) {
      return false;
    }

    const transition = nextLifecycleTransition(order.status);
    if (!transition) {
      transaction.update(orderRef, {
        lifecycleDemoEnabled: false,
        nextLifecycleAt: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return false;
    }

    const isDelivered = transition.status === "delivered";
    transaction.update(orderRef, {
      [transition.timestampField]: FieldValue.serverTimestamp(),
      lifecycleDemoEnabled: !isDelivered,
      nextLifecycleAt: isDelivered ?
        FieldValue.delete() :
        Timestamp.fromMillis(
          Date.now() + DEMO_LIFECYCLE_DELAY_SECONDS * 1000,
        ),
      status: transition.status,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return true;
  });
}

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
