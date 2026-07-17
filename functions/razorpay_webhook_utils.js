"use strict";

const crypto = require("node:crypto");

class RazorpayWebhookPayloadError extends Error {}

function verifyRazorpayWebhookSignature({payload, razorpaySignature, secret}) {
  if (!Buffer.isBuffer(payload) ||
    typeof razorpaySignature !== "string" ||
    typeof secret !== "string") {
    return false;
  }

  const generated = crypto
    .createHmac("sha256", secret)
    .update(payload)
    .digest("hex");
  const generatedBuffer = Buffer.from(generated, "utf8");
  const suppliedBuffer = Buffer.from(razorpaySignature, "utf8");

  return generatedBuffer.length === suppliedBuffer.length &&
    crypto.timingSafeEqual(generatedBuffer, suppliedBuffer);
}

function webhookEventId(payload) {
  if (!Buffer.isBuffer(payload)) {
    throw new RazorpayWebhookPayloadError("Webhook body must be raw bytes.");
  }

  return crypto.createHash("sha256").update(payload).digest("hex");
}

function parseRazorpayWebhookEvent(payload) {
  if (!isRecord(payload)) {
    throw new RazorpayWebhookPayloadError("Webhook payload must be an object.");
  }

  const eventName = requiredString(payload.event, "Webhook event");
  switch (eventName) {
    case "payment.captured": {
      const payment = parsePayment(payload);
      return {...payment, eventName, kind: "paymentCaptured"};
    }
    case "payment.failed": {
      const payment = parsePayment(payload);
      return {...payment, eventName, kind: "paymentFailed"};
    }
    case "refund.created":
    case "refund.processed":
    case "refund.failed": {
      const refund = parseRefund(payload);
      return {...refund, eventName, kind: "refund"};
    }
    default:
      return {eventName, kind: "ignored"};
  }
}

function parsePayment(payload) {
  const payment = payload.payload?.payment?.entity;
  if (!isRecord(payment)) {
    throw new RazorpayWebhookPayloadError("Webhook payment payload is missing.");
  }

  const amount = Number(payment.amount);
  if (!Number.isSafeInteger(amount) || amount <= 0) {
    throw new RazorpayWebhookPayloadError("Webhook payment amount is invalid.");
  }

  return {
    amount,
    currency: requiredString(payment.currency, "Webhook payment currency"),
    failureCode: optionalString(payment.error_code),
    failureReason: optionalString(payment.error_description),
    razorpayOrderId: requiredString(payment.order_id, "Webhook Razorpay order ID"),
    razorpayPaymentId: requiredString(payment.id, "Webhook Razorpay payment ID"),
  };
}

function parseRefund(payload) {
  const refund = payload.payload?.refund?.entity;
  if (!isRecord(refund)) {
    throw new RazorpayWebhookPayloadError("Webhook refund payload is missing.");
  }

  const amount = Number(refund.amount);
  const createdAt = Number(refund.created_at);
  const status = requiredString(refund.status, "Webhook refund status");
  if (!Number.isSafeInteger(amount) || amount <= 0 ||
    !Number.isSafeInteger(createdAt) || createdAt <= 0 ||
    !["pending", "processed", "failed"].includes(status)) {
    throw new RazorpayWebhookPayloadError("Webhook refund data is invalid.");
  }

  return {
    amount,
    created_at: createdAt,
    id: requiredString(refund.id, "Webhook refund ID"),
    payment_id: requiredString(refund.payment_id, "Webhook refund payment ID"),
    speed_processed: optionalString(refund.speed_processed),
    speed_requested: optionalString(refund.speed_requested),
    status,
  };
}

function requiredString(value, label) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new RazorpayWebhookPayloadError(`${label} is invalid.`);
  }
  return value.trim();
}

function optionalString(value) {
  return typeof value === "string" && value.trim().length > 0 ?
    value.trim() : null;
}

function isRecord(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

module.exports = {
  RazorpayWebhookPayloadError,
  parseRazorpayWebhookEvent,
  verifyRazorpayWebhookSignature,
  webhookEventId,
};
