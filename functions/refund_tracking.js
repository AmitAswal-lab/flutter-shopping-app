"use strict";

const {FieldValue} = require("firebase-admin/firestore");

const {normalizeRefund} = require("./razorpay_refund_service");

async function applyRefundStatus({db, gatewayRefund}) {
  const refund = normalizeRefund(gatewayRefund);
  const trackingRef = db.collection("refunds").doc(refund.id);

  return db.runTransaction(async (transaction) => {
    const trackingSnapshot = await transaction.get(trackingRef);
    if (!trackingSnapshot.exists) {
      throw new Error(`Refund tracking document ${refund.id} was not found.`);
    }

    const tracking = trackingSnapshot.data();
    const orderRef = db.doc(tracking.orderPath);
    const orderSnapshot = await transaction.get(orderRef);
    if (!orderSnapshot.exists) {
      throw new Error(`Refund order ${tracking.orderPath} was not found.`);
    }

    const updates = {
      refundStatus: refund.status,
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (refund.status === "processed") {
      updates.refundProcessedAt = FieldValue.serverTimestamp();
    } else if (refund.status === "failed") {
      updates.refundFailedAt = FieldValue.serverTimestamp();
    }

    transaction.update(orderRef, updates);
    transaction.update(trackingRef, {
      status: refund.status,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return refund;
  });
}

module.exports = {applyRefundStatus};
