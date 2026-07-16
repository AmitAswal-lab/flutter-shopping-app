"use strict";

const {FieldValue, Timestamp} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");

const {canCancelOrder} = require("./order_cancellation_utils");
const {parseStoredOrderItems} = require("./payment_utils");

const DEFAULT_CANCELLATION_LEASE_MILLIS = 2 * 60 * 1000;

async function claimOrderCancellation({
  db,
  leaseMillis = DEFAULT_CANCELLATION_LEASE_MILLIS,
  nowMillis = Date.now(),
  orderRef,
  processingToken,
  userId,
}) {
  return db.runTransaction(async (transaction) => {
    const orderSnapshot = await transaction.get(orderRef);
    if (!orderSnapshot.exists) {
      throw new HttpsError("not-found", "Order was not found.");
    }

    const order = orderSnapshot.data();
    if (order.status === "cancelled") {
      return {
        result: cancellationResult(orderRef.id, order),
        state: "completed",
      };
    }

    let activeToken = processingToken;
    let previousStatus = order.status;
    if (order.status === "cancellationPending") {
      const startedAt = order.cancellationProcessingStartedAt;
      const startedAtMillis = startedAt instanceof Timestamp ?
        startedAt.toMillis() : 0;
      if (startedAtMillis > nowMillis - leaseMillis) {
        throw new HttpsError(
          "aborted",
          "Order cancellation is already being processed.",
        );
      }

      activeToken = order.cancellationProcessingToken || processingToken;
      previousStatus = order.cancellationPreviousStatus || "paid";
    } else {
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
    }

    const paymentId = stringValue(order.razorpayPaymentId);
    const requiresRefund = paymentId.length > 0;
    const amount = Number(order.totalPriceCents);
    if (requiresRefund && (!Number.isSafeInteger(amount) || amount <= 0)) {
      throw new HttpsError(
        "failed-precondition",
        "The paid order does not have a valid refundable amount.",
      );
    }

    transaction.update(orderRef, {
      cancellationPreviousStatus: previousStatus,
      cancellationProcessingStartedAt: FieldValue.serverTimestamp(),
      cancellationProcessingToken: activeToken,
      cancellationReason: "customerRequested",
      cancellationRequestedAt: order.cancellationRequestedAt ||
        FieldValue.serverTimestamp(),
      cancellationRequestedBy: userId,
      lifecycleDemoEnabled: false,
      nextLifecycleAt: FieldValue.delete(),
      refundStatus: requiresRefund ? "initiating" : "notRequired",
      status: "cancellationPending",
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {
      amount,
      orderId: orderRef.id,
      paymentId,
      processingToken: activeToken,
      requiresRefund,
      state: "claimed",
    };
  });
}

async function finalizeOrderCancellation({
  db,
  orderRef,
  processingToken,
  refund = null,
  userId,
}) {
  return db.runTransaction(async (transaction) => {
    const orderSnapshot = await transaction.get(orderRef);
    if (!orderSnapshot.exists) {
      throw new HttpsError("not-found", "Order was not found.");
    }

    const order = orderSnapshot.data();
    if (order.status === "cancelled") {
      return cancellationResult(orderRef.id, order);
    }
    if (
      order.status !== "cancellationPending" ||
      order.cancellationProcessingToken !== processingToken
    ) {
      throw new HttpsError(
        "aborted",
        "Order cancellation was interrupted. Try again.",
      );
    }

    const items = parseStoredOrderItems(order.items);
    if (order.stockRestored !== true) {
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
    }

    const refundStatus = refund?.status || "notRequired";
    const updates = {
      cancelledAt: FieldValue.serverTimestamp(),
      cancelledBy: userId,
      cancellationProcessingStartedAt: FieldValue.delete(),
      cancellationProcessingToken: FieldValue.delete(),
      lifecycleDemoEnabled: false,
      nextLifecycleAt: FieldValue.delete(),
      refundStatus,
      status: "cancelled",
      stockRestored: true,
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (refund) {
      Object.assign(updates, refundOrderFields(refund));
      const trackingRef = db.collection("refunds").doc(refund.id);
      transaction.set(trackingRef, {
        amount: refund.amount,
        createdAt: Timestamp.fromMillis(refund.createdAt * 1000),
        orderId: orderRef.id,
        orderPath: orderRef.path,
        paymentId: refund.paymentId,
        refundId: refund.id,
        status: refund.status,
        updatedAt: FieldValue.serverTimestamp(),
        userId,
      }, {merge: true});
    }

    transaction.update(orderRef, updates);
    return cancellationResult(orderRef.id, {
      ...order,
      ...updates,
      refundStatus,
      status: "cancelled",
    });
  });
}

async function releaseFailedCancellation({
  errorMessage,
  orderRef,
  processingToken,
}) {
  await orderRef.firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(orderRef);
    if (!snapshot.exists) return;

    const order = snapshot.data();
    if (
      order.status !== "cancellationPending" ||
      order.cancellationProcessingToken !== processingToken
    ) {
      return;
    }

    transaction.update(orderRef, {
      cancellationFailedAt: FieldValue.serverTimestamp(),
      cancellationFailureMessage: errorMessage,
      cancellationProcessingStartedAt: FieldValue.delete(),
      cancellationProcessingToken: FieldValue.delete(),
      refundStatus: "notRequired",
      status: order.cancellationPreviousStatus || "paid",
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

function refundOrderFields(refund) {
  const fields = {
    refundAmountCents: refund.amount,
    refundCreatedAt: Timestamp.fromMillis(refund.createdAt * 1000),
    refundId: refund.id,
    refundPaymentId: refund.paymentId,
    refundSpeedProcessed: refund.speedProcessed || null,
    refundSpeedRequested: refund.speedRequested || null,
  };
  if (refund.status === "processed") {
    fields.refundProcessedAt = FieldValue.serverTimestamp();
  }
  if (refund.status === "failed") {
    fields.refundFailedAt = FieldValue.serverTimestamp();
  }
  return fields;
}

function cancellationResult(orderId, order) {
  return {
    orderId,
    refundId: stringValue(order.refundId) || null,
    refundStatus: order.refundStatus || "notRequired",
    status: order.status,
  };
}

function stringValue(value) {
  return typeof value === "string" ? value : "";
}

module.exports = {
  claimOrderCancellation,
  finalizeOrderCancellation,
  releaseFailedCancellation,
};
