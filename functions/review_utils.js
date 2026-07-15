"use strict";

class ReviewInputError extends Error {}

function parseReviewRequest(data) {
  const productId = parseProductId(data);
  if (!Number.isInteger(data.rating) || data.rating < 1 || data.rating > 5) {
    throw new ReviewInputError("Rating must be an integer from 1 to 5.");
  }
  if (typeof data.comment !== "string") {
    throw new ReviewInputError("Review comment must be a string.");
  }
  const comment = data.comment.trim();
  if (comment.length < 3 || comment.length > 1000) {
    throw new ReviewInputError(
      "Review comment must be between 3 and 1000 characters.",
    );
  }
  return {productId, rating: data.rating, comment};
}

function parseReviewDeleteRequest(data) {
  return {productId: parseProductId(data)};
}

function parseProductId(data) {
  if (data === null || typeof data !== "object" || Array.isArray(data)) {
    throw new ReviewInputError("Review data is required.");
  }
  if (typeof data.productId !== "string") {
    throw new ReviewInputError("Product ID must be a string.");
  }
  const productId = data.productId.trim();
  if (
    productId.length < 1 ||
    productId.length > 128 ||
    !/^[A-Za-z0-9_-]+$/.test(productId)
  ) {
    throw new ReviewInputError("Product ID is invalid.");
  }
  return productId;
}

function updatedAggregate({
  product,
  previousRating,
  nextRating,
}) {
  const currentCount = Number.isInteger(product.reviewCount) ?
    product.reviewCount :
    0;
  const currentRating =
    typeof product.rating === "number" && Number.isFinite(product.rating) ?
      product.rating :
      0;
  const currentSum =
    typeof product.ratingSum === "number" &&
    Number.isFinite(product.ratingSum) ?
      product.ratingSum :
      currentRating * currentCount;

  let reviewCount = currentCount;
  let ratingSum = currentSum;
  if (previousRating !== null) {
    ratingSum -= previousRating;
  } else if (nextRating !== null) {
    reviewCount += 1;
  }

  if (nextRating !== null) {
    ratingSum += nextRating;
  } else if (previousRating !== null) {
    reviewCount = Math.max(0, reviewCount - 1);
  }

  ratingSum = Math.max(0, ratingSum);
  const rating = reviewCount === 0 ?
    0 :
    Number((ratingSum / reviewCount).toFixed(2));
  return {rating, ratingSum, reviewCount};
}

module.exports = {
  ReviewInputError,
  parseReviewDeleteRequest,
  parseReviewRequest,
  updatedAggregate,
};
