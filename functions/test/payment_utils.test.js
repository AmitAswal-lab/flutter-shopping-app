"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  PaymentInputError,
  parsePaymentRequest,
  parseRazorpayOrderRequest,
  parseRazorpayVerificationRequest,
  parseStoredOrderItems,
} = require("../payment_utils");

test("parses a supported non-success payment outcome", () => {
  assert.deepEqual(
    parsePaymentRequest({
      orderId: "order_123",
      outcome: "paymentFailed",
    }),
    {
      orderId: "order_123",
      outcome: "paymentFailed",
    },
  );
});

test("prevents clients from marking their own payment paid", () => {
  assert.throws(
    () =>
      parsePaymentRequest({
        orderId: "order_123",
        outcome: "paid",
      }),
    PaymentInputError,
  );
});

test("parses Razorpay order creation input", () => {
  assert.deepEqual(parseRazorpayOrderRequest({orderId: "order_123"}), {
    orderId: "order_123",
  });
});

test("parses Razorpay verification fields", () => {
  assert.deepEqual(
    parseRazorpayVerificationRequest({
      orderId: "order_123",
      razorpayOrderId: "order_gateway_123",
      razorpayPaymentId: "pay_123",
      razorpaySignature: "a".repeat(64),
    }),
    {
      orderId: "order_123",
      razorpayOrderId: "order_gateway_123",
      razorpayPaymentId: "pay_123",
      razorpaySignature: "a".repeat(64),
    },
  );
});

test("rejects unsupported payment outcomes", () => {
  assert.throws(
    () =>
      parsePaymentRequest({
        orderId: "order_123",
        outcome: "refunded",
      }),
    PaymentInputError,
  );
});

test("rejects invalid order IDs", () => {
  assert.throws(
    () =>
      parsePaymentRequest({
        orderId: "bad/id",
        outcome: "paid",
      }),
    PaymentInputError,
  );
});

test("parses the trusted fields needed to restore inventory", () => {
  assert.deepEqual(
    parseStoredOrderItems([
      {
        productId: "p1",
        name: "Headphones",
        priceCents: 7999,
        quantity: 2,
      },
    ]),
    [{productId: "p1", quantity: 2}],
  );
});

test("rejects invalid stored order quantities", () => {
  assert.throws(
    () =>
      parseStoredOrderItems([
        {
          productId: "p1",
          quantity: 0,
        },
      ]),
    PaymentInputError,
  );
});
