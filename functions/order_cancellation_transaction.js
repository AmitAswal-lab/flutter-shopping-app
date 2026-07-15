"use strict";

const {FieldValue} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");

const {canCancelOrder} = require("./order_cancellation_utils");
const {parseStoredOrderItems} = require("./payment_utils");

async function cancelOrder({db, orderRef, userId}) {
  return db.runTransaction(async (transaction) => {
    const orderSnapshot = await transaction.get(orderRef);
    if (!orderSnapshot.exists) {
      throw new HttpsError("not-found", "Order was not found.");
    }

    const order = orderSnapshot.data();
    if (order.status === "cancelled") {
      return cancellationResult(orderRef.id, order);
    }
    if (!canCancelOrder(order.status)) {
      throw new HttpsError(
        "failed-precondition",
        "This order can no longer be cancelled.",
      );
    }
    if (order.stockRestored === true) {
      throw new HttpsError(
        "failed-precondition",
        "Inventory for this order was already restored.",
      );
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
          "Order inventory could not be restored.",
        );
      }

      transaction.update(productRefs[index], {
        stockCount: FieldValue.increment(items[index].quantity),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    const requiresRefund =
      typeof order.razorpayPaymentId === "string" &&
      order.razorpayPaymentId.length > 0;
    const refundStatus = requiresRefund ? "pending" : "notRequired";

    transaction.update(orderRef, {
      cancelledAt: FieldValue.serverTimestamp(),
      cancelledBy: userId,
      cancellationReason: "customerRequested",
      lifecycleDemoEnabled: false,
      nextLifecycleAt: FieldValue.delete(),
      refundStatus,
      status: "cancelled",
      stockRestored: true,
      updatedAt: FieldValue.serverTimestamp(),
    });

    return cancellationResult(orderRef.id, {
      ...order,
      refundStatus,
      status: "cancelled",
    });
  });
}

function cancellationResult(orderId, order) {
  return {
    orderId,
    refundStatus: order.refundStatus || "notRequired",
    status: order.status,
  };
}

module.exports = {cancelOrder};
