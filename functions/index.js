"use strict";

const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {initializeApp} = require("firebase-admin/app");
const {logger} = require("firebase-functions");
const {onCall, HttpsError} = require("firebase-functions/v2/https");

const {
  CheckoutInputError,
  parseCheckoutRequest,
} = require("./order_utils");

initializeApp();

const db = getFirestore();

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

        transaction.create(orderRef, {
          id: orderRef.id,
          customerName,
          deliveryAddress: checkout.deliveryAddress,
          createdAt: FieldValue.serverTimestamp(),
          items: orderItems,
          totalPriceCents,
          status: "confirmed",
        });

        return {
          orderId: orderRef.id,
          customerName,
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
