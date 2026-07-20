"use strict";

const ORDER_NOTIFICATIONS = new Map([
  ["paid", {
    title: "Payment successful",
    body: (itemLabel) => `Payment received for ${itemLabel}.`,
  }],
  ["processing", {
    title: "Preparing your order",
    body: (itemLabel) => `${itemLabel} is being prepared.`,
  }],
  ["shipped", {
    title: "Order shipped",
    body: (itemLabel) => `${itemLabel} is on its way.`,
  }],
  ["delivered", {
    title: "Order delivered",
    body: (itemLabel) => `${itemLabel} has been delivered.`,
  }],
  ["cancelled", {
    title: "Order cancelled",
    body: (itemLabel) => `${itemLabel} was cancelled.`,
  }],
]);

const REFUND_NOTIFICATIONS = new Map([
  ["processed", {
    title: "Refund processed",
    body: (itemLabel) => `Refund for ${itemLabel} was processed.`,
  }],
  ["failed", {
    title: "Refund needs attention",
    body: (itemLabel) =>
      `Refund for ${itemLabel} could not be processed.`,
  }],
]);

function notificationForStatus(status, itemLabel) {
  const definition = ORDER_NOTIFICATIONS.get(status);
  if (!definition || typeof itemLabel !== "string" || itemLabel.length === 0) {
    return null;
  }

  return {
    body: definition.body(itemLabel),
    title: definition.title,
  };
}

function notificationForRefundStatus(status, itemLabel) {
  const definition = REFUND_NOTIFICATIONS.get(status);
  if (!definition || typeof itemLabel !== "string" || itemLabel.length === 0) {
    return null;
  }

  return {
    body: definition.body(itemLabel),
    title: definition.title,
  };
}

function notificationItemLabel(items) {
  if (!Array.isArray(items)) return "Your order";

  const itemNames = items
    .map((item) => typeof item?.name === "string" ? item.name.trim() : "")
    .filter(Boolean);
  if (itemNames.length === 0) return "Your order";
  if (itemNames.length === 1) return itemNames[0];

  const remainingItemCount = itemNames.length - 1;
  const itemWord = remainingItemCount === 1 ? "item" : "items";
  return `${itemNames[0]} and ${remainingItemCount} other ${itemWord}`;
}

function isInvalidRegistrationError(error) {
  return error?.code === "messaging/registration-token-not-registered" ||
    error?.code === "messaging/invalid-registration-token";
}

module.exports = {
  isInvalidRegistrationError,
  notificationItemLabel,
  notificationForRefundStatus,
  notificationForStatus,
};
