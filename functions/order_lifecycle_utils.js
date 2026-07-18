"use strict";

const LIFECYCLE_TRANSITIONS = new Map([
  ["paid", {status: "processing", timestampField: "processingAt"}],
  ["confirmed", {status: "processing", timestampField: "processingAt"}],
  ["processing", {status: "shipped", timestampField: "shippedAt"}],
  ["shipped", {status: "delivered", timestampField: "deliveredAt"}],
]);

class OrderFulfillmentInputError extends Error {}

function parseOrderFulfillmentRequest(data) {
  if (data === null || typeof data !== "object" || Array.isArray(data)) {
    throw new OrderFulfillmentInputError("Order data is required.");
  }

  const orderId = parseDocumentId(data.orderId, "Order ID");
  const userId = parseDocumentId(data.userId, "User ID");

  return {orderId, userId};
}

function parseDocumentId(value, label) {
  if (typeof value !== "string") {
    throw new OrderFulfillmentInputError(`${label} must be a string.`);
  }

  const id = value.trim();
  if (id.length < 3 || id.length > 128 || !/^[A-Za-z0-9_-]+$/.test(id)) {
    throw new OrderFulfillmentInputError(`${label} is invalid.`);
  }

  return id;
}

function nextLifecycleTransition(status) {
  return LIFECYCLE_TRANSITIONS.get(status) || null;
}

module.exports = {
  OrderFulfillmentInputError,
  nextLifecycleTransition,
  parseOrderFulfillmentRequest,
};
