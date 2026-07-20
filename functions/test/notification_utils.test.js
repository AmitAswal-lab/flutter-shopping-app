"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  isInvalidRegistrationError,
  notificationItemLabel,
  notificationForRefundStatus,
  notificationForStatus,
} = require("../notification_utils");

test("builds notifications only for customer-facing order statuses", () => {
  assert.deepEqual(notificationForStatus("paid", "Mini Speaker"), {
    body: "Payment received for Mini Speaker.",
    title: "Payment successful",
  });
  assert.deepEqual(notificationForStatus("processing", "Mini Speaker"), {
    body: "Mini Speaker is being prepared.",
    title: "Preparing your order",
  });
  assert.deepEqual(notificationForStatus("shipped", "Mini Speaker"), {
    body: "Mini Speaker is on its way.",
    title: "Order shipped",
  });
  assert.deepEqual(notificationForStatus("delivered", "Mini Speaker"), {
    body: "Mini Speaker has been delivered.",
    title: "Order delivered",
  });
  assert.deepEqual(notificationForStatus("cancelled", "Mini Speaker"), {
    body: "Mini Speaker was cancelled.",
    title: "Order cancelled",
  });
  assert.equal(notificationForStatus("paymentFailed", "Mini Speaker"), null);
  assert.equal(notificationForStatus("paid", ""), null);
});

test("builds notifications for completed and failed refunds", () => {
  assert.deepEqual(notificationForRefundStatus("processed", "Mini Speaker"), {
    body: "Refund for Mini Speaker was processed.",
    title: "Refund processed",
  });
  assert.deepEqual(notificationForRefundStatus("failed", "Mini Speaker"), {
    body: "Refund for Mini Speaker could not be processed.",
    title: "Refund needs attention",
  });
  assert.equal(notificationForRefundStatus("pending", "order_1"), null);
});

test("creates concise labels from order items", () => {
  assert.equal(notificationItemLabel([{name: "Mini Speaker"}]), "Mini Speaker");
  assert.equal(
    notificationItemLabel([{name: "Mini Speaker"}, {name: "Wireless Headphones"}]),
    "Mini Speaker and 1 other item",
  );
  assert.equal(notificationItemLabel([]), "Your order");
  assert.equal(notificationItemLabel(null), "Your order");
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
