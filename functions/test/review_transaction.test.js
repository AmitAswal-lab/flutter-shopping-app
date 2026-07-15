"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {deleteApp, initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {removeReview, upsertReview} = require("../review_transaction");

const PROJECT_ID = "shopping-app-review-test";
let adminApp;
let db;
let environment;

test.before(async () => {
  environment = await initializeTestEnvironment({projectId: PROJECT_ID});
  adminApp = initializeApp({projectId: PROJECT_ID}, "review-test");
  db = getFirestore(adminApp);
});

test.beforeEach(async () => {
  await environment.clearFirestore();
});

test.after(async () => {
  await deleteApp(adminApp);
  await environment.cleanup();
});

test("one user review can be created, edited, and removed", async () => {
  await seedProduct({rating: 4, reviewCount: 2});
  await seedUser("alice");

  await submit("alice", 5, "Excellent product.");
  let product = (await db.doc("products/p1").get()).data();
  assert.equal(product.reviewCount, 3);
  assert.equal(product.ratingSum, 13);
  assert.equal(product.rating, 4.33);
  assert.equal(
    (await db.collection("products/p1/reviews").get()).size,
    1,
  );

  await submit("alice", 1, "Changed my mind.");
  product = (await db.doc("products/p1").get()).data();
  assert.equal(product.reviewCount, 3);
  assert.equal(product.ratingSum, 9);
  assert.equal(product.rating, 3);

  await removeReview({db, productId: "p1", userId: "alice"});
  product = (await db.doc("products/p1").get()).data();
  assert.equal(product.reviewCount, 2);
  assert.equal(product.ratingSum, 8);
  assert.equal(product.rating, 4);
  assert.equal(
    (await db.collection("products/p1/reviews").get()).size,
    0,
  );
});

test("concurrent reviews produce one consistent aggregate", async () => {
  await Promise.all([
    seedProduct({rating: 0, reviewCount: 0}),
    seedUser("alice"),
    seedUser("bob"),
  ]);

  await Promise.all([
    submit("alice", 5, "Excellent product."),
    submit("bob", 3, "A decent product."),
  ]);

  const product = (await db.doc("products/p1").get()).data();
  assert.equal(product.reviewCount, 2);
  assert.equal(product.ratingSum, 8);
  assert.equal(product.rating, 4);
  assert.equal(
    (await db.collection("products/p1/reviews").get()).size,
    2,
  );
});

async function seedProduct({rating, reviewCount}) {
  await db.doc("products/p1").set({
    isActive: true,
    name: "Headphones",
    rating,
    reviewCount,
  });
}

async function seedUser(userId) {
  await db.doc(`users/${userId}`).set({displayName: userId});
}

async function submit(userId, rating, comment) {
  return upsertReview({
    authEmail: `${userId}@example.com`,
    comment,
    db,
    productId: "p1",
    rating,
    userId,
  });
}
