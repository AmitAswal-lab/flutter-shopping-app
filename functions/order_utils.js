"use strict";

const MAX_CART_ITEMS = 50;

class CheckoutInputError extends Error {}

function parseCheckoutRequest(data) {
  if (data === null || typeof data !== "object" || Array.isArray(data)) {
    throw new CheckoutInputError("Checkout data is required.");
  }

  const checkoutId = requireTrimmedString(
    data.checkoutId,
    "Checkout ID",
    8,
    128,
  );
  if (!/^[A-Za-z0-9_-]+$/.test(checkoutId)) {
    throw new CheckoutInputError("Checkout ID is invalid.");
  }

  const deliveryAddress = requireTrimmedString(
    data.deliveryAddress,
    "Delivery address",
    3,
    500,
  );

  if (
    !Array.isArray(data.productIds) ||
    data.productIds.length === 0 ||
    data.productIds.length > MAX_CART_ITEMS
  ) {
    throw new CheckoutInputError(
      `Checkout must contain between 1 and ${MAX_CART_ITEMS} products.`,
    );
  }

  const productIds = [...new Set(data.productIds.map(parseProductId))];

  return {checkoutId, deliveryAddress, productIds};
}

function parseProductId(value) {
  return requireTrimmedString(value, "Product ID", 1, 128);
}

function requireTrimmedString(value, label, minimum, maximum) {
  if (typeof value !== "string") {
    throw new CheckoutInputError(`${label} must be a string.`);
  }

  const trimmed = value.trim();
  if (trimmed.length < minimum || trimmed.length > maximum) {
    throw new CheckoutInputError(
      `${label} must be between ${minimum} and ${maximum} characters.`,
    );
  }
  return trimmed;
}

module.exports = {
  CheckoutInputError,
  parseCheckoutRequest,
};
