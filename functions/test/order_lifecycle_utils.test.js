"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  OrderLifecycleInputError,
  nextLifecycleTransition,
  parseOrderLifecycleRequest,
} = require("../order_lifecycle_utils");

test("parses a valid lifecycle request", () => {
  assert.deepEqual(
    parseOrderLifecycleRequest({orderId: "order_123"}),
    {orderId: "order_123"},
  );
});

test("rejects an invalid lifecycle order ID", () => {
  assert.throws(
    () => parseOrderLifecycleRequest({orderId: "../order"}),
    OrderLifecycleInputError,
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
