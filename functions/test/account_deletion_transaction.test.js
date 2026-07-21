"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {deleteApp, initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");

const {
  deleteCustomerFirestoreData,
} = require("../account_deletion");

const PROJECT_ID = "shopping-app-account-deletion-test";
let adminApp;
let db;
let environment;

test.before(async () => {
  environment = await initializeTestEnvironment({projectId: PROJECT_ID});
  adminApp = initializeApp({projectId: PROJECT_ID}, "account-deletion-test");
  db = getFirestore(adminApp);
});

test.beforeEach(async () => {
  await environment.clearFirestore();
});

test.after(async () => {
  await deleteApp(adminApp);
  await environment.cleanup();
});

test("removes personal data while retaining anonymized transactions", async () => {
  const userRef = db.doc("users/alice");
  const orderRef = userRef.collection("orders").doc("order_123");
  await Promise.all([
    userRef.set({displayName: "Alice", phoneNumber: "1234567890"}),
    userRef.collection("cartItems").doc("p1").set({quantity: 1}),
    userRef.collection("deliveryAddresses").doc("home").set({
      address: "123 Test Street",
    }),
    userRef.collection("deviceRegistrations").doc("phone").set({
      token: "secret-token",
    }),
    orderRef.set({
      customerName: "Alice",
      deliveryAddress: "Alice\n123 Test Street\n1234567890",
      deliveryAddressId: "home",
      deliveryPhoneNumber: "1234567890",
      deliveryRecipient: "Alice",
      items: [{name: "Headphones", priceCents: 7999, quantity: 1}],
      status: "delivered",
      totalPriceCents: 7999,
    }),
    db.doc("products/p1").set({
      rating: 5,
      ratingSum: 5,
      reviewCount: 1,
    }),
    db.doc("products/p1/reviews/alice").set({
      comment: "Excellent",
      rating: 5,
      userId: "alice",
    }),
    db.doc("refunds/refund_123").set({
      orderPath: orderRef.path,
      status: "processed",
      userId: "alice",
    }),
  ]);

  const result = await deleteCustomerFirestoreData({db, userId: "alice"});
  const user = (await userRef.get()).data();
  const order = (await orderRef.get()).data();
  const product = (await db.doc("products/p1").get()).data();
  const refund = (await db.doc("refunds/refund_123").get()).data();

  assert.equal(result.removedReviewCount, 1);
  assert.equal(result.retainedOrderCount, 1);
  assert.equal(user.accountDeleted, true);
  assert.equal(user.displayName, undefined);
  assert.equal((await userRef.collection("cartItems").get()).empty, true);
  assert.equal((await userRef.collection("deliveryAddresses").get()).empty, true);
  assert.equal((await userRef.collection("deviceRegistrations").get()).empty, true);
  assert.equal(order.customerName, "Deleted customer");
  assert.equal(order.deliveryAddress, undefined);
  assert.equal(order.status, "delivered");
  assert.equal(product.reviewCount, 0);
  assert.equal(product.rating, 0);
  assert.equal((await db.doc("products/p1/reviews/alice").get()).exists, false);
  assert.equal(refund.userId, undefined);
  assert.equal(refund.orderPath, orderRef.path);
});

test("keeps the account intact while an order is active", async () => {
  const userRef = db.doc("users/alice");
  await userRef.set({displayName: "Alice"});
  await userRef.collection("orders").doc("order_123").set({status: "shipped"});
  await userRef.collection("cartItems").doc("p1").set({quantity: 1});

  await assert.rejects(
    deleteCustomerFirestoreData({db, userId: "alice"}),
    (error) => error.code === "failed-precondition",
  );

  assert.equal((await userRef.get()).data().displayName, "Alice");
  assert.equal((await userRef.collection("cartItems").get()).size, 1);
});
