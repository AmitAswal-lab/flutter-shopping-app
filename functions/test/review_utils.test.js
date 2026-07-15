"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  ReviewInputError,
  parseReviewRequest,
  updatedAggregate,
} = require("../review_utils");

test("parses and trims a valid review", () => {
  assert.deepEqual(parseReviewRequest({
    productId: "p1",
    rating: 5,
    comment: "  Excellent product.  ",
  }), {
    productId: "p1",
    rating: 5,
    comment: "Excellent product.",
  });
});

test("rejects invalid ratings and short comments", () => {
  assert.throws(
    () => parseReviewRequest({productId: "p1", rating: 6, comment: "Great"}),
    ReviewInputError,
  );
  assert.throws(
    () => parseReviewRequest({productId: "p1", rating: 5, comment: "x"}),
    ReviewInputError,
  );
});

test("adds a new rating to an existing aggregate", () => {
  assert.deepEqual(updatedAggregate({
    product: {rating: 4, reviewCount: 2, ratingSum: 8},
    previousRating: null,
    nextRating: 5,
  }), {
    rating: 4.33,
    ratingSum: 13,
    reviewCount: 3,
  });
});

test("updates a rating without increasing review count", () => {
  assert.deepEqual(updatedAggregate({
    product: {rating: 4, reviewCount: 2, ratingSum: 8},
    previousRating: 3,
    nextRating: 5,
  }), {
    rating: 5,
    ratingSum: 10,
    reviewCount: 2,
  });
});

test("removes a rating from the aggregate", () => {
  assert.deepEqual(updatedAggregate({
    product: {rating: 4, reviewCount: 2, ratingSum: 8},
    previousRating: 3,
    nextRating: null,
  }), {
    rating: 5,
    ratingSum: 5,
    reviewCount: 1,
  });
});
