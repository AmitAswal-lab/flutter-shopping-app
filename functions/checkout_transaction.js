"use strict";

const {
  FieldValue,
  Timestamp,
} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");

const PENDING_PAYMENT = "pendingPayment";

async function reserveCheckout({
  authEmail,
  checkout,
  db,
  paymentReservationMinutes,
  userId,
}) {
  const userRef = db.collection("users").doc(userId);
  const orderRef = userRef.collection("orders").doc(checkout.checkoutId);
  const cartRefs = checkout.productIds.map((productId) =>
    userRef.collection("cartItems").doc(productId),
  );
  const productRefs = checkout.productIds.map((productId) =>
    db.collection("products").doc(productId),
  );

  return db.runTransaction(async (transaction) => {
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
    const email = typeof authEmail === "string" ? authEmail : "";
    const customerName = fullName || displayName || email || "Shopper";
    const reservationExpiresAt = Timestamp.fromMillis(
      Date.now() + paymentReservationMinutes * 60 * 1000,
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
}

module.exports = {reserveCheckout};
