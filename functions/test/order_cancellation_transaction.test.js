"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {deleteApp, initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");

const {cancelOrder} = require("../order_cancellation_transaction");

const PROJECT_ID = "shopping-app-cancellation-test";
let adminApp;
let db;
let environment;

test.before(async () => {
  environment = await initializeTestEnvironment({projectId: PROJECT_ID});
  adminApp = initializeApp({projectId: PROJECT_ID}, "cancellation-test");
  db = getFirestore(adminApp);
});

test.beforeEach(async () => {
  await environment.clearFirestore();
});

test.after(async () => {
  await deleteApp(adminApp);
  await environment.cleanup();
});

test("cancelling an order restores stock exactly once", async () => {
  await seedProduct("p1", 3);
  const orderRef = await seedOrder("paid", 2);

  const [first, second] = await Promise.all([
    cancelOrder({db, orderRef, userId: "alice"}),
    cancelOrder({db, orderRef, userId: "alice"}),
  ]);
  const order = (await orderRef.get()).data();

  assert.equal(first.status, "cancelled");
  assert.equal(second.status, "cancelled");
  assert.equal((await db.doc("products/p1").get()).data().stockCount, 5);
  assert.equal(order.status, "cancelled");
  assert.equal(order.stockRestored, true);
  assert.equal(order.refundStatus, "pending");
});

test("processing orders can be cancelled and stop their demo", async () => {
  await seedProduct("p1", 3);
  const orderRef = await seedOrder("processing", 1);

  await cancelOrder({db, orderRef, userId: "alice"});
  const order = (await orderRef.get()).data();

  assert.equal(order.lifecycleDemoEnabled, false);
  assert.equal(order.nextLifecycleAt, undefined);
  assert.equal((await db.doc("products/p1").get()).data().stockCount, 4);
});

test("shipped orders cannot be cancelled", async () => {
  await seedProduct("p1", 3);
  const orderRef = await seedOrder("shipped", 1);

  await assert.rejects(
    cancelOrder({db, orderRef, userId: "alice"}),
    (error) => error.code === "failed-precondition",
  );
  assert.equal((await db.doc("products/p1").get()).data().stockCount, 3);
});

async function seedProduct(productId, stockCount) {
  await db.doc(`products/${productId}`).set({
    isActive: true,
    name: "Headphones",
    priceCents: 7999,
    stockCount,
  });
}

async function seedOrder(status, quantity) {
  const orderRef = db.doc("users/alice/orders/order_123");
  await orderRef.set({
    items: [{
      name: "Headphones",
      priceCents: 7999,
      productId: "p1",
      quantity,
    }],
    lifecycleDemoEnabled: true,
    nextLifecycleAt: new Date(Date.now() + 30_000),
    razorpayPaymentId: "pay_test_123",
    status,
    stockRestored: false,
  });
  return orderRef;
}
