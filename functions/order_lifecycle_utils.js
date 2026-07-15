"use strict";

const LIFECYCLE_TRANSITIONS = new Map([
  ["paid", {status: "processing", timestampField: "processingAt"}],
  ["confirmed", {status: "processing", timestampField: "processingAt"}],
  ["processing", {status: "shipped", timestampField: "shippedAt"}],
  ["shipped", {status: "delivered", timestampField: "deliveredAt"}],
]);

class OrderLifecycleInputError extends Error {}

function parseOrderLifecycleRequest(data) {
  if (data === null || typeof data !== "object" || Array.isArray(data)) {
    throw new OrderLifecycleInputError("Order data is required.");
  }

  if (typeof data.orderId !== "string") {
    throw new OrderLifecycleInputError("Order ID must be a string.");
  }

  const orderId = data.orderId.trim();
  if (
    orderId.length < 8 ||
    orderId.length > 128 ||
    !/^[A-Za-z0-9_-]+$/.test(orderId)
  ) {
    throw new OrderLifecycleInputError("Order ID is invalid.");
  }

  return {orderId};
}

function nextLifecycleTransition(status) {
  return LIFECYCLE_TRANSITIONS.get(status) || null;
}

module.exports = {
  OrderLifecycleInputError,
  nextLifecycleTransition,
  parseOrderLifecycleRequest,
};
