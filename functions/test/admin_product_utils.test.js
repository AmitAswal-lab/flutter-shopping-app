"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  AdminProductInputError,
  parseAdminProductRequest,
} = require("../admin_product_utils");

const validProduct = {
  brand: "Auralux",
  category: "audio",
  description: "Balanced wireless headphones.",
  imageStoragePath: "product-images/p13/image.png",
  imageUrl: "https://example.com/image.png",
  isActive: true,
  listPriceCents: 11999,
  name: "Wireless Headphones",
  priceCents: 7999,
  productId: "p13",
  sortOrder: 13,
  stockCount: 20,
};

test("parses and trims trusted catalog fields", () => {
  const parsed = parseAdminProductRequest({
    ...validProduct,
    brand: "  Auralux ",
  });

  assert.equal(parsed.brand, "Auralux");
  assert.equal(parsed.productId, "p13");
  assert.equal(parsed.priceCents, 7999);
  assert.equal(parsed.imageStoragePath, "product-images/p13/image.png");
});

test("rejects invalid prices, categories, and image URLs", () => {
  assert.throws(
    () => parseAdminProductRequest({...validProduct, priceCents: -1}),
    AdminProductInputError,
  );
  assert.throws(
    () => parseAdminProductRequest({...validProduct, category: "unknown"}),
    AdminProductInputError,
  );
  assert.throws(
    () => parseAdminProductRequest({
      ...validProduct,
      imageUrl: "http://example.com/image.png",
    }),
    AdminProductInputError,
  );
});

test("requires list price to be at least the selling price", () => {
  assert.throws(
    () => parseAdminProductRequest({
      ...validProduct,
      listPriceCents: 7000,
    }),
    AdminProductInputError,
  );
});
