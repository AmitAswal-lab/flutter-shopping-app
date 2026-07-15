"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {deleteApp, initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {reserveCheckout} = require("../checkout_transaction");

const PROJECT_ID = "shopping-app-checkout-test";
let adminApp;
let db;
let environment;

test.before(async () => {
  environment = await initializeTestEnvironment({projectId: PROJECT_ID});
  adminApp = initializeApp({projectId: PROJECT_ID}, "checkout-test");
  db = getFirestore(adminApp);
});

test.beforeEach(async () => {
  await environment.clearFirestore();
});

test.after(async () => {
  await deleteApp(adminApp);
  await environment.cleanup();
});

test("repeated checkout IDs reserve stock only once", async () => {
  await seedUserCart("alice", "p1", 1);
  await seedProduct("p1", 2);
  const checkout = checkoutInput("checkout_same", "p1");

  const first = await reserveCheckout({
    authEmail: "alice@example.com",
    checkout,
    db,
    paymentReservationMinutes: 15,
    userId: "alice",
  });
  const second = await reserveCheckout({
    authEmail: "alice@example.com",
    checkout,
    db,
    paymentReservationMinutes: 15,
    userId: "alice",
  });

  assert.equal(first.orderId, second.orderId);
  assert.equal((await db.doc("products/p1").get()).data().stockCount, 1);
  assert.equal(
    (await db.collection("users/alice/orders").get()).size,
    1,
  );
});

test("concurrent buyers cannot reserve the same final stock unit", async () => {
  await Promise.all([
    seedUserCart("alice", "p1", 1),
    seedUserCart("bob", "p1", 1),
    seedProduct("p1", 1),
  ]);

  const results = await Promise.allSettled([
    reserveCheckout({
      authEmail: "alice@example.com",
      checkout: checkoutInput("checkout_alice", "p1"),
      db,
      paymentReservationMinutes: 15,
      userId: "alice",
    }),
    reserveCheckout({
      authEmail: "bob@example.com",
      checkout: checkoutInput("checkout_bob", "p1"),
      db,
      paymentReservationMinutes: 15,
      userId: "bob",
    }),
  ]);

  const fulfilled = results.filter((result) => result.status === "fulfilled");
  const rejected = results.filter((result) => result.status === "rejected");
  const aliceOrders = await db.collection("users/alice/orders").get();
  const bobOrders = await db.collection("users/bob/orders").get();

  assert.equal(fulfilled.length, 1);
  assert.equal(rejected.length, 1);
  assert.equal((await db.doc("products/p1").get()).data().stockCount, 0);
  assert.equal(aliceOrders.size + bobOrders.size, 1);
});

function checkoutInput(checkoutId, productId) {
  return {
    checkoutId,
    deliveryAddress: "123 Test Street",
    paymentMethod: "razorpay",
    productIds: [productId],
  };
}

async function seedUserCart(userId, productId, quantity) {
  await Promise.all([
    db.doc(`users/${userId}`).set({displayName: userId}),
    db.doc(`users/${userId}/cartItems/${productId}`).set({
      name: "Headphones",
      priceCents: 7999,
      productId,
      quantity,
    }),
  ]);
}

async function seedProduct(productId, stockCount) {
  await db.doc(`products/${productId}`).set({
    isActive: true,
    name: "Headphones",
    priceCents: 7999,
    stockCount,
  });
}
