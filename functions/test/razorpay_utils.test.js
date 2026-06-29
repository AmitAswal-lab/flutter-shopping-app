"use strict";

const crypto = require("node:crypto");
const test = require("node:test");
const assert = require("node:assert/strict");

const {verifyRazorpaySignature} = require("../razorpay_utils");

test("accepts a valid Razorpay HMAC signature", () => {
  const secret = "test_secret";
  const razorpayOrderId = "order_123";
  const razorpayPaymentId = "pay_123";
  const razorpaySignature = crypto
    .createHmac("sha256", secret)
    .update(`${razorpayOrderId}|${razorpayPaymentId}`)
    .digest("hex");

  assert.equal(
    verifyRazorpaySignature({
      razorpayOrderId,
      razorpayPaymentId,
      razorpaySignature,
      secret,
    }),
    true,
  );
});

test("rejects an invalid Razorpay HMAC signature", () => {
  assert.equal(
    verifyRazorpaySignature({
      razorpayOrderId: "order_123",
      razorpayPaymentId: "pay_123",
      razorpaySignature: "0".repeat(64),
      secret: "test_secret",
    }),
    false,
  );
});
