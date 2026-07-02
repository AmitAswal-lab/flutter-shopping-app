"use strict";

const {FieldValue} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");
const {updatedAggregate} = require("./review_utils");

async function upsertReview({
  authEmail,
  comment,
  db,
  productId,
  rating,
  userId,
}) {
  const productRef = db.collection("products").doc(productId);
  const reviewRef = productRef.collection("reviews").doc(userId);
  const userRef = db.collection("users").doc(userId);

  return db.runTransaction(async (transaction) => {
    const [productSnapshot, reviewSnapshot, userSnapshot] =
      await transaction.getAll(productRef, reviewRef, userRef);
    if (
      !productSnapshot.exists ||
      productSnapshot.data().isActive === false
    ) {
      throw new HttpsError("not-found", "Product was not found.");
    }

    const previousReview = reviewSnapshot.exists ?
      reviewSnapshot.data() :
      null;
    const previousRating = previousReview?.rating;
    if (
      previousRating !== undefined &&
      (!Number.isInteger(previousRating) ||
        previousRating < 1 ||
        previousRating > 5)
    ) {
      throw new HttpsError("internal", "Stored review rating is invalid.");
    }

    const profile = userSnapshot.exists ? userSnapshot.data() : {};
    const profileName =
      typeof profile.displayName === "string" ?
        profile.displayName.trim() :
        "";
    const fullName =
      typeof profile.fullName === "string" ? profile.fullName.trim() : "";
    const email = typeof authEmail === "string" ? authEmail : "";
    const displayName = profileName || fullName || email || "Shopper";
    const aggregate = updatedAggregate({
      product: productSnapshot.data(),
      previousRating: previousRating ?? null,
      nextRating: rating,
    });

    transaction.set(reviewRef, {
      comment,
      createdAt: previousReview?.createdAt || FieldValue.serverTimestamp(),
      displayName,
      rating,
      updatedAt: FieldValue.serverTimestamp(),
      userId,
    });
    transaction.update(productRef, {
      ...aggregate,
      updatedAt: FieldValue.serverTimestamp(),
    });

    return aggregate;
  });
}

async function removeReview({db, productId, userId}) {
  const productRef = db.collection("products").doc(productId);
  const reviewRef = productRef.collection("reviews").doc(userId);

  return db.runTransaction(async (transaction) => {
    const [productSnapshot, reviewSnapshot] =
      await transaction.getAll(productRef, reviewRef);
    if (!productSnapshot.exists) {
      throw new HttpsError("not-found", "Product was not found.");
    }
    if (!reviewSnapshot.exists) {
      return {
        rating: productSnapshot.data().rating,
        ratingSum: productSnapshot.data().ratingSum,
        reviewCount: productSnapshot.data().reviewCount,
      };
    }

    const previousRating = reviewSnapshot.data().rating;
    if (
      !Number.isInteger(previousRating) ||
      previousRating < 1 ||
      previousRating > 5
    ) {
      throw new HttpsError("internal", "Stored review rating is invalid.");
    }

    const aggregate = updatedAggregate({
      product: productSnapshot.data(),
      previousRating,
      nextRating: null,
    });
    transaction.delete(reviewRef);
    transaction.update(productRef, {
      ...aggregate,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return aggregate;
  });
}

module.exports = {removeReview, upsertReview};
