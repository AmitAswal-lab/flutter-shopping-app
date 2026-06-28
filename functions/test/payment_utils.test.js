"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  PaymentInputError,
  parsePaymentRequest,
  parseStoredOrderItems,
} = require("../payment_utils");

test("parses a supported payment outcome", () => {
  assert.deepEqual(
    parsePaymentRequest({
      orderId: "order_123",
      outcome: "paid",
    }),
    {
      orderId: "order_123",
      outcome: "paid",
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
