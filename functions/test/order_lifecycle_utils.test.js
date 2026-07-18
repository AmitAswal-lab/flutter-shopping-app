"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  OrderFulfillmentInputError,
  nextLifecycleTransition,
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
