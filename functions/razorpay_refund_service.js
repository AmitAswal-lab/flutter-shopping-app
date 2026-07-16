"use strict";

const crypto = require("node:crypto");

async function createOrRecoverRefund({
  amount,
  orderId,
  paymentId,
  processingToken,
  razorpay,
  userId,
}) {
  const receipt = refundReceipt(orderId);
  const existing = await findExistingRefund({
    paymentId,
    processingToken,
    razorpay,
    receipt,
  });
  if (existing) return normalizeRefund(existing);

  const refund = await razorpay.payments.refund(paymentId, {
    amount,
    notes: {
      appOrderId: orderId,
      appUserId: userId,
      cancellationToken: processingToken,
    },
    receipt,
    speed: "normal",
  });
  return normalizeRefund(refund);
}

async function findExistingRefund({
  paymentId,
  processingToken,
  razorpay,
  receipt,
}) {
  const response = await razorpay.payments.fetchMultipleRefund(paymentId, {
    count: 100,
  });
  const refunds = Array.isArray(response?.items) ? response.items : [];
  return refunds.find((refund) =>
    refund.receipt === receipt ||
    refund.notes?.cancellationToken === processingToken,
  );
}

function normalizeRefund(refund) {
  const amount = Number(refund?.amount);
  const createdAt = Number(refund?.created_at);
  if (
    typeof refund?.id !== "string" ||
    typeof refund?.payment_id !== "string" ||
    !Number.isSafeInteger(amount) ||
    !Number.isSafeInteger(createdAt) ||
    !["pending", "processed", "failed"].includes(refund?.status)
  ) {
    throw new Error("Razorpay returned an invalid refund response.");
  }

  return {
    amount,
    createdAt,
    id: refund.id,
    paymentId: refund.payment_id,
    speedProcessed: stringValue(refund.speed_processed),
    speedRequested: stringValue(refund.speed_requested),
    status: refund.status,
  };
}

function refundReceipt(orderId) {
  const digest = crypto.createHash("sha256").update(orderId).digest("hex");
  return `cancel_${digest.slice(0, 24)}`;
}

function stringValue(value) {
  return typeof value === "string" && value.length > 0 ? value : null;
}

module.exports = {
  createOrRecoverRefund,
  normalizeRefund,
  refundReceipt,
};
