"use strict";

const CANCELLABLE_ORDER_STATUSES = new Set([
  "paid",
  "confirmed",
  "processing",
]);

class OrderCancellationInputError extends Error {}

function parseOrderCancellationRequest(data) {
  const orderId = data?.orderId;
  if (
    typeof orderId !== "string" ||
    orderId.length < 8 ||
    orderId.length > 128 ||
    !/^[A-Za-z0-9_-]+$/.test(orderId)
  ) {
    throw new OrderCancellationInputError("Order ID is invalid.");
  }

  return {orderId};
}

function canCancelOrder(status) {
  return CANCELLABLE_ORDER_STATUSES.has(status);
}

module.exports = {
  OrderCancellationInputError,
  canCancelOrder,
  parseOrderCancellationRequest,
};
