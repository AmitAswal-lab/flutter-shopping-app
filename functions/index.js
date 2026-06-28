"use strict";

const {
  getFirestore,
  FieldValue,
  Timestamp,
} = require("firebase-admin/firestore");
const {initializeApp} = require("firebase-admin/app");
const {logger} = require("firebase-functions");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");

const {
  CheckoutInputError,
  parseCheckoutRequest,
} = require("./order_utils");
const {
  PaymentInputError,
  parsePaymentRequest,
  parseStoredOrderItems,
} = require("./payment_utils");

initializeApp();

const db = getFirestore();
const PAYMENT_RESERVATION_MINUTES = 15;
const PENDING_PAYMENT = "pendingPayment";

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

exports.expirePaymentReservations = onSchedule(
  {
    region: "us-central1",
    schedule: "every 15 minutes",
    timeZone: "UTC",
  },
  async () => {
    const expiredReservations = await db
      .collectionGroup("orders")
      .where("reservationExpiresAt", "<=", Timestamp.now())
      .limit(50)
      .get();

    let expiredCount = 0;
    for (const order of expiredReservations.docs) {
      if (order.data().status !== PENDING_PAYMENT) continue;

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

      if (outcome === "paid") {
        transaction.update(orderRef, {
          paidAt: FieldValue.serverTimestamp(),
          status: "paid",
          updatedAt: FieldValue.serverTimestamp(),
        });
        return paymentResult(orderRef.id, {...order, status: "paid"});
      }

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

function paymentResult(orderId, order) {
  return {
    orderId,
    customerName: order.customerName,
    paymentMethod: order.paymentMethod,
    status: order.status,
    totalPriceCents: order.totalPriceCents,
  };
}
