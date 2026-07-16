"use strict";

const ORDER_NOTIFICATIONS = new Map([
  ["paid", {
    title: "Payment successful",
    body: (orderId) => `Payment received for order #${shortOrderId(orderId)}.`,
  }],
  ["processing", {
    title: "Preparing your order",
    body: (orderId) => `Order #${shortOrderId(orderId)} is being prepared.`,
  }],
  ["shipped", {
    title: "Order shipped",
    body: (orderId) => `Order #${shortOrderId(orderId)} is on its way.`,
  }],
  ["delivered", {
    title: "Order delivered",
    body: (orderId) => `Order #${shortOrderId(orderId)} has been delivered.`,
  }],
  ["cancelled", {
    title: "Order cancelled",
    body: (orderId) => `Order #${shortOrderId(orderId)} was cancelled.`,
  }],
]);

const REFUND_NOTIFICATIONS = new Map([
  ["processed", {
    title: "Refund processed",
    body: (orderId) =>
      `The refund for order #${shortOrderId(orderId)} was processed.`,
  }],
  ["failed", {
    title: "Refund needs attention",
    body: (orderId) =>
      `The refund for order #${shortOrderId(orderId)} could not be processed.`,
  }],
]);

function notificationForStatus(status, orderId) {
  const definition = ORDER_NOTIFICATIONS.get(status);
  if (!definition || typeof orderId !== "string" || orderId.length === 0) {
    return null;
  }

  return {
    body: definition.body(orderId),
    title: definition.title,
  };
}

function notificationForRefundStatus(status, orderId) {
  const definition = REFUND_NOTIFICATIONS.get(status);
  if (!definition || typeof orderId !== "string" || orderId.length === 0) {
    return null;
  }

  return {
    body: definition.body(orderId),
    title: definition.title,
  };
}

function isInvalidRegistrationError(error) {
  return error?.code === "messaging/registration-token-not-registered" ||
    error?.code === "messaging/invalid-registration-token";
}

function shortOrderId(orderId) {
  return orderId.length <= 8 ? orderId : orderId.slice(0, 8);
}

module.exports = {
  isInvalidRegistrationError,
  notificationForRefundStatus,
  notificationForStatus,
};
