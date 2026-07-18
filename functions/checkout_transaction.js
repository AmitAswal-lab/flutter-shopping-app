"use strict";

const { FieldValue, Timestamp } = require("firebase-admin/firestore");
const { HttpsError } = require("firebase-functions/v2/https");

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
  const deliveryAddressRef = userRef
    .collection("deliveryAddresses")
    .doc(checkout.deliveryAddressId);
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
      deliveryAddressRef,
      ...cartRefs,
      ...productRefs,
    );
    const userSnapshot = snapshots[0];
    const deliveryAddressSnapshot = snapshots[1];
    const cartSnapshots = snapshots.slice(2, 2 + cartRefs.length);
    const productSnapshots = snapshots.slice(2 + cartRefs.length);

    if (!deliveryAddressSnapshot.exists) {
      throw new HttpsError(
        "failed-precondition",
        "Choose a saved delivery address before checkout.",
      );
    }
    const delivery = parseDeliveryAddress(deliveryAddressSnapshot.data());

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
          { productId },
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
          { productId },
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
          { productId },
        );
      }
      if (stockCount < quantity) {
        throw new HttpsError(
          "failed-precondition",
          `Only ${stockCount} ${productName} available.`,
          { productId, availableStock: stockCount },
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
      typeof profile.displayName === "string" ? profile.displayName.trim() : "";
    const email = typeof authEmail === "string" ? authEmail : "";
    const customerName = fullName || displayName || email || "Shopper";
    const reservationExpiresAt = Timestamp.fromMillis(
      Date.now() + paymentReservationMinutes * 60 * 1000,
    );

    transaction.create(orderRef, {
      id: orderRef.id,
      customerName,
      deliveryAddress: delivery.formattedAddress,
      deliveryAddressId: deliveryAddressRef.id,
      deliveryRecipient: delivery.fullName,
      deliveryPhoneNumber: delivery.phoneNumber,
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

function parseDeliveryAddress(data) {
  const address = typeof data.address === "string" ? data.address.trim() : "";
  const fullName =
    typeof data.fullName === "string" ? data.fullName.trim() : "";
  const phoneNumber =
    typeof data.phoneNumber === "string" ? data.phoneNumber.trim() : "";

  if (
    !fullName ||
    fullName.length > 100 ||
    address.length < 3 ||
    address.length > 500
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Your saved delivery address is incomplete. Update it before checkout.",
    );
  }
  if (phoneNumber.length > 30) {
    throw new HttpsError(
      "failed-precondition",
      "Your saved phone number is invalid. Update the address before checkout.",
    );
  }

  return {
    address,
    formattedAddress: [fullName, address, phoneNumber]
      .filter(Boolean)
      .join("\n"),
    fullName,
    phoneNumber,
  };
}

module.exports = { reserveCheckout };
