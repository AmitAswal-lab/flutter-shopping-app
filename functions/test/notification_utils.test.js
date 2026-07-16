"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  isInvalidRegistrationError,
  notificationForRefundStatus,
  notificationForStatus,
} = require("../notification_utils");

test("builds notifications only for customer-facing order statuses", () => {
  assert.deepEqual(notificationForStatus("paid", "order_123456789"), {
    body: "Payment received for order #order_12.",
    title: "Payment successful",
  });
  assert.deepEqual(notificationForStatus("processing", "order_1"), {
    body: "Order #order_1 is being prepared.",
    title: "Preparing your order",
  });
  assert.deepEqual(notificationForStatus("shipped", "order_1"), {
    body: "Order #order_1 is on its way.",
    title: "Order shipped",
  });
  assert.deepEqual(notificationForStatus("delivered", "order_1"), {
    body: "Order #order_1 has been delivered.",
    title: "Order delivered",
  });
  assert.deepEqual(notificationForStatus("cancelled", "order_1"), {
    body: "Order #order_1 was cancelled.",
    title: "Order cancelled",
  });
  assert.equal(notificationForStatus("paymentFailed", "order_1"), null);
  assert.equal(notificationForStatus("paid", ""), null);
});

test("builds notifications for completed and failed refunds", () => {
  assert.deepEqual(notificationForRefundStatus("processed", "order_123456789"), {
    body: "The refund for order #order_12 was processed.",
    title: "Refund processed",
  });
  assert.deepEqual(notificationForRefundStatus("failed", "order_1"), {
    body: "The refund for order #order_1 could not be processed.",
    title: "Refund needs attention",
  });
  assert.equal(notificationForRefundStatus("pending", "order_1"), null);
});

test("recognizes messaging errors that require registration cleanup", () => {
  assert.equal(isInvalidRegistrationError({
    code: "messaging/registration-token-not-registered",
  }), true);
  assert.equal(isInvalidRegistrationError({
    code: "messaging/invalid-registration-token",
  }), true);
  assert.equal(isInvalidRegistrationError({
    code: "messaging/internal-error",
  }), false);
});
