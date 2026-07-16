"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {deleteApp, initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");

const {
  claimOrderCancellation,
  finalizeOrderCancellation,
} = require("../order_cancellation_transaction");

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

test("stock returns only after a Razorpay refund is accepted", async () => {
  await seedProduct("p1", 3);
  const orderRef = await seedOrder("paid", 2);

  const claim = await claimOrderCancellation({
    db,
    orderRef,
    processingToken: "token_123",
    userId: "alice",
  });
  const claimedOrder = (await orderRef.get()).data();

  assert.equal(claim.state, "claimed");
  assert.equal(claimedOrder.status, "cancellationPending");
  assert.equal(claimedOrder.refundStatus, "initiating");
  assert.equal((await db.doc("products/p1").get()).data().stockCount, 3);

  const refund = {
    amount: 15998,
    createdAt: 1_700_000_000,
    id: "rfnd_123",
    paymentId: "pay_test_123",
    speedProcessed: "normal",
    speedRequested: "normal",
    status: "pending",
  };
  const first = await finalizeOrderCancellation({
    db,
    orderRef,
    processingToken: claim.processingToken,
    refund,
    userId: "alice",
  });
  const second = await finalizeOrderCancellation({
    db,
    orderRef,
    processingToken: claim.processingToken,
    refund,
    userId: "alice",
  });
  const order = (await orderRef.get()).data();

  assert.equal(first.status, "cancelled");
  assert.equal(second.status, "cancelled");
  assert.equal((await db.doc("products/p1").get()).data().stockCount, 5);
  assert.equal(order.status, "cancelled");
  assert.equal(order.stockRestored, true);
  assert.equal(order.refundStatus, "pending");
  assert.equal(order.refundId, "rfnd_123");
  assert.equal((await db.doc("refunds/rfnd_123").get()).data().status, "pending");
});

test("only one cancellation claim can be active at a time", async () => {
  await seedProduct("p1", 3);
  const orderRef = await seedOrder("processing", 1);

  await claimOrderCancellation({
    db,
    orderRef,
    processingToken: "token_first",
    userId: "alice",
  });
  const order = (await orderRef.get()).data();

  assert.equal(order.lifecycleDemoEnabled, false);
  assert.equal(order.nextLifecycleAt, undefined);
  assert.equal((await db.doc("products/p1").get()).data().stockCount, 3);
  await assert.rejects(
    claimOrderCancellation({
      db,
      orderRef,
      processingToken: "token_second",
      userId: "alice",
    }),
    (error) => error.code === "aborted",
  );
});

test("shipped orders cannot be cancelled", async () => {
  await seedProduct("p1", 3);
  const orderRef = await seedOrder("shipped", 1);

  await assert.rejects(
    claimOrderCancellation({
      db,
      orderRef,
      processingToken: "token_123",
      userId: "alice",
    }),
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
    totalPriceCents: quantity * 7999,
  });
  return orderRef;
}
