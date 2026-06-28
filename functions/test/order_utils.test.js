"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  CheckoutInputError,
  parseCheckoutRequest,
} = require("../order_utils");

test("parses and deduplicates checkout product IDs", () => {
  const result = parseCheckoutRequest({
    checkoutId: "checkout_123",
    deliveryAddress: "123 Test Street",
    paymentMethod: "testCard",
    productIds: ["p1", "p2", "p1"],
  });

  assert.deepEqual(result, {
    checkoutId: "checkout_123",
    deliveryAddress: "123 Test Street",
    paymentMethod: "testCard",
    productIds: ["p1", "p2"],
  });
});

test("rejects empty carts", () => {
  assert.throws(
    () =>
      parseCheckoutRequest({
        checkoutId: "checkout_123",
        deliveryAddress: "123 Test Street",
        paymentMethod: "testCard",
        productIds: [],
      }),
    CheckoutInputError,
  );
});

test("rejects invalid checkout IDs", () => {
  assert.throws(
    () =>
      parseCheckoutRequest({
        checkoutId: "bad/id",
        deliveryAddress: "123 Test Street",
        paymentMethod: "testCard",
        productIds: ["p1"],
      }),
    CheckoutInputError,
  );
});

test("rejects unsupported payment methods", () => {
  assert.throws(
    () =>
      parseCheckoutRequest({
        checkoutId: "checkout_123",
        deliveryAddress: "123 Test Street",
        paymentMethod: "unknown",
        productIds: ["p1"],
      }),
    CheckoutInputError,
  );
});
