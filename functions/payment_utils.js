"use strict";

const PAYMENT_OUTCOMES = new Set(["paid", "paymentFailed", "cancelled"]);

class PaymentInputError extends Error {}

function parsePaymentRequest(data) {
  if (data === null || typeof data !== "object" || Array.isArray(data)) {
    throw new PaymentInputError("Payment data is required.");
  }

  const orderId = requireTrimmedString(data.orderId, "Order ID", 8, 128);
  if (!/^[A-Za-z0-9_-]+$/.test(orderId)) {
    throw new PaymentInputError("Order ID is invalid.");
  }

  const outcome = requireTrimmedString(data.outcome, "Payment outcome", 1, 32);
  if (!PAYMENT_OUTCOMES.has(outcome)) {
    throw new PaymentInputError("Payment outcome is invalid.");
  }

  return {orderId, outcome};
}

function parseStoredOrderItems(value) {
  if (!Array.isArray(value) || value.length === 0) {
    throw new PaymentInputError("Order items are invalid.");
  }

  return value.map((item) => {
    if (
      item === null ||
      typeof item !== "object" ||
      typeof item.productId !== "string" ||
      !Number.isInteger(item.quantity) ||
      item.quantity <= 0
    ) {
      throw new PaymentInputError("Order items are invalid.");
    }
    return {
      productId: item.productId,
      quantity: item.quantity,
    };
  });
}

function requireTrimmedString(value, label, minimum, maximum) {
  if (typeof value !== "string") {
    throw new PaymentInputError(`${label} must be a string.`);
  }

  const trimmed = value.trim();
  if (trimmed.length < minimum || trimmed.length > maximum) {
    throw new PaymentInputError(
      `${label} must be between ${minimum} and ${maximum} characters.`,
    );
  }
  return trimmed;
}

module.exports = {
  PaymentInputError,
  parsePaymentRequest,
  parseStoredOrderItems,
};
