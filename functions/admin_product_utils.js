"use strict";

class AdminProductInputError extends Error {}

const PRODUCT_ID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;
const CATEGORIES = new Set(["audio", "wearable", "accessory"]);

function parseAdminProductRequest(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw new AdminProductInputError("Product data is required.");
  }

  const productId = readString(data, "productId", 128);
  if (!PRODUCT_ID_PATTERN.test(productId)) {
    throw new AdminProductInputError("Product ID is invalid.");
  }

  const category = readString(data, "category", 40);
  if (!CATEGORIES.has(category)) {
    throw new AdminProductInputError("Product category is invalid.");
  }

  const priceCents = readInteger(data, "priceCents", 0, 100000000);
  const listPriceCents = readInteger(
    data,
    "listPriceCents",
    priceCents,
    100000000,
  );

  return {
    brand: readString(data, "brand", 120),
    category,
    description: readString(data, "description", 2000),
    imageStoragePath: readOptionalString(data, "imageStoragePath", 500),
    imageUrl: readOptionalUrl(data, "imageUrl"),
    isActive: readBoolean(data, "isActive"),
    listPriceCents,
    name: readString(data, "name", 200),
    priceCents,
    productId,
    sortOrder: readInteger(data, "sortOrder", 0, 1000000),
    stockCount: readInteger(data, "stockCount", 0, 1000000),
  };
}

function readString(data, field, maximum) {
  const value = data[field];
  if (
    typeof value !== "string" ||
    value.trim().length === 0 ||
    value.trim().length > maximum
  ) {
    throw new AdminProductInputError(
      `${field} must be between 1 and ${maximum} characters.`,
    );
  }
  return value.trim();
}

function readOptionalString(data, field, maximum) {
  const value = data[field];
  if (value == null || value === "") return null;
  if (typeof value !== "string" || value.length > maximum) {
    throw new AdminProductInputError(`${field} is invalid.`);
  }
  return value;
}

function readOptionalUrl(data, field) {
  const value = readOptionalString(data, field, 2048);
  if (value == null) return null;

  let url;
  try {
    url = new URL(value);
  } catch (_) {
    throw new AdminProductInputError(`${field} must be a valid HTTPS URL.`);
  }
  if (url.protocol !== "https:") {
    throw new AdminProductInputError(`${field} must be a valid HTTPS URL.`);
  }
  return value;
}

function readInteger(data, field, minimum, maximum) {
  const value = data[field];
  if (
    !Number.isInteger(value) ||
    value < minimum ||
    value > maximum
  ) {
    throw new AdminProductInputError(
      `${field} must be an integer from ${minimum} to ${maximum}.`,
    );
  }
  return value;
}

function readBoolean(data, field) {
  if (typeof data[field] !== "boolean") {
    throw new AdminProductInputError(`${field} must be true or false.`);
  }
  return data[field];
}

module.exports = {
  AdminProductInputError,
  parseAdminProductRequest,
};
