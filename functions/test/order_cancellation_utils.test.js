"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  OrderCancellationInputError,
  canCancelOrder,
  parseOrderCancellationRequest,
} = require("../order_cancellation_utils");

test("parses a valid cancellation request", () => {
  assert.deepEqual(
    parseOrderCancellationRequest({orderId: "order_123"}),
    {orderId: "order_123"},
  );
});

test("rejects an invalid cancellation order ID", () => {
  assert.throws(
    () => parseOrderCancellationRequest({orderId: "../order"}),
    OrderCancellationInputError,
  );
});

test("allows cancellation only before shipment", () => {
  assert.equal(canCancelOrder("paid"), true);
  assert.equal(canCancelOrder("confirmed"), true);
  assert.equal(canCancelOrder("processing"), true);
  assert.equal(canCancelOrder("shipped"), false);
  assert.equal(canCancelOrder("delivered"), false);
  assert.equal(canCancelOrder("cancelled"), false);
});
