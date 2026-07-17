"use strict";

const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const test = require("node:test");

const {
  RazorpayWebhookPayloadError,
  parseRazorpayWebhookEvent,
  verifyRazorpayWebhookSignature,
  webhookEventId,
} = require("../razorpay_webhook_utils");

test("accepts a valid Razorpay webhook HMAC based on the raw body", () => {
  const secret = "webhook_secret";
  const payload = Buffer.from('{"event":"payment.captured"}', "utf8");
  const signature = crypto
    .createHmac("sha256", secret)
    .update(payload)
    .digest("hex");

  assert.equal(
    verifyRazorpayWebhookSignature({
      payload,
      razorpaySignature: signature,
      secret,
    }),
    true,
  );
  assert.equal(webhookEventId(payload).length, 64);
});

test("rejects an invalid Razorpay webhook HMAC", () => {
  assert.equal(
    verifyRazorpayWebhookSignature({
      payload: Buffer.from("{}", "utf8"),
      razorpaySignature: "invalid",
      secret: "webhook_secret",
    }),
    false,
  );
});

test("parses a captured payment webhook", () => {
  assert.deepEqual(
    parseRazorpayWebhookEvent({
      event: "payment.captured",
      payload: {
        payment: {
          entity: {
            amount: 4999,
            currency: "INR",
            id: "pay_123",
            order_id: "order_123",
          },
        },
      },
    }),
    {
      amount: 4999,
      currency: "INR",
      eventName: "payment.captured",
      failureCode: null,
      failureReason: null,
      kind: "paymentCaptured",
      razorpayOrderId: "order_123",
      razorpayPaymentId: "pay_123",
    },
  );
});

test("parses a processed refund webhook", () => {
  assert.deepEqual(
    parseRazorpayWebhookEvent({
      event: "refund.processed",
      payload: {
        refund: {
          entity: {
            amount: 4999,
            created_at: 1760000000,
            id: "rfnd_123",
            payment_id: "pay_123",
            speed_processed: "normal",
            speed_requested: "normal",
            status: "processed",
          },
        },
      },
    }),
    {
      amount: 4999,
      created_at: 1760000000,
      eventName: "refund.processed",
      id: "rfnd_123",
      kind: "refund",
      payment_id: "pay_123",
      speed_processed: "normal",
      speed_requested: "normal",
      status: "processed",
    },
  );
});

test("ignores unhandled webhook events and rejects malformed handled events", () => {
  assert.deepEqual(
    parseRazorpayWebhookEvent({event: "subscription.activated"}),
    {eventName: "subscription.activated", kind: "ignored"},
  );
  assert.throws(
    () => parseRazorpayWebhookEvent({event: "payment.captured"}),
    RazorpayWebhookPayloadError,
  );
});
