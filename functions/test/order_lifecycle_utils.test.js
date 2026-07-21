"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  OrderFulfillmentInputError,
  nextLifecycleTransition,
  nextVerifiedLifecycleTransition,
  parseOrderFulfillmentRequest,
} = require("../order_lifecycle_utils");

test("parses a valid order fulfillment request", () => {
  assert.deepEqual(
    parseOrderFulfillmentRequest({
      orderId: "order_123",
      userId: "customer_123",
    }),
    {orderId: "order_123", userId: "customer_123"},
  );
});

test("rejects invalid order fulfillment document IDs", () => {
  assert.throws(
    () => parseOrderFulfillmentRequest({
      orderId: "../order",
      userId: "customer_123",
    }),
    OrderFulfillmentInputError,
  );
  assert.throws(
    () => parseOrderFulfillmentRequest({orderId: "order_123"}),
    OrderFulfillmentInputError,
  );
});

test("returns ordered lifecycle transitions", () => {
  assert.deepEqual(nextLifecycleTransition("paid"), {
    status: "processing",
    timestampField: "processingAt",
  });
  assert.equal(nextLifecycleTransition("confirmed"), null);
  assert.deepEqual(nextLifecycleTransition("processing"), {
    status: "shipped",
    timestampField: "shippedAt",
  });
  assert.deepEqual(nextLifecycleTransition("shipped"), {
    status: "delivered",
    timestampField: "deliveredAt",
  });
  assert.equal(nextLifecycleTransition("delivered"), null);
});

test("requires Razorpay capture evidence before fulfillment starts", () => {
  assert.equal(
    nextVerifiedLifecycleTransition({
      paymentMethod: "razorpay",
      status: "paid",
    }),
    null,
  );
  assert.deepEqual(
    nextVerifiedLifecycleTransition({
      paymentMethod: "razorpay",
      razorpayPaymentId: "pay_123",
      status: "paid",
    }),
    {status: "processing", timestampField: "processingAt"},
  );
});
