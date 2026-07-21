"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {deleteApp, initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");

const {
  reconcileRazorpayWebhook,
} = require("../webhook_reconciliation");

const PROJECT_ID = "shopping-app-late-payment-test";
let adminApp;
let db;
let environment;

test.before(async () => {
  environment = await initializeTestEnvironment({projectId: PROJECT_ID});
  adminApp = initializeApp({projectId: PROJECT_ID}, "late-payment-test");
  db = getFirestore(adminApp);
});

test.beforeEach(async () => {
  await environment.clearFirestore();
});

test.after(async () => {
  await deleteApp(adminApp);
  await environment.cleanup();
});

test("refunds a capture received after reserved inventory was released", async () => {
  await db.doc("products/p1").set({stockCount: 5});
  const orderRef = db.doc("users/alice/orders/order_123");
  await orderRef.set({
    customerName: "Alice",
    items: [{
      name: "Headphones",
      priceCents: 7999,
      productId: "p1",
      quantity: 2,
    }],
    paymentMethod: "razorpay",
    paymentProvider: "razorpay",
    razorpayOrderId: "order_gateway_123",
    status: "expired",
    stockRestored: true,
    totalPriceCents: 15998,
  });

  let refundCreateCount = 0;
  const razorpay = {
    payments: {
      fetchMultipleRefund: async () => ({items: []}),
      refund: async (paymentId, input) => {
        refundCreateCount += 1;
        return {
          amount: input.amount,
          created_at: 1_700_000_000,
          id: "rfnd_late_123",
          payment_id: paymentId,
          speed_processed: "normal",
          speed_requested: "normal",
          status: "processed",
        };
      },
    },
  };
  const event = {
    amount: 15998,
    currency: "INR",
    eventName: "payment.captured",
    kind: "paymentCaptured",
    razorpayOrderId: "order_gateway_123",
    razorpayPaymentId: "pay_late_123",
  };

  const first = await reconcileRazorpayWebhook({
    db,
    event,
    eventId: "event_late_123",
    razorpay,
  });
  const second = await reconcileRazorpayWebhook({
    db,
    event,
    eventId: "event_late_123",
    razorpay,
  });
  const order = (await orderRef.get()).data();
  const refund = (await db.doc("refunds/rfnd_late_123").get()).data();

  assert.equal(first.action, "latePaymentRefundProcessed");
  assert.equal(second.action, "duplicate");
  assert.equal(refundCreateCount, 1);
  assert.equal(order.status, "cancelled");
  assert.equal(order.stockRestored, true);
  assert.equal(order.razorpayPaymentId, "pay_late_123");
  assert.equal(order.refundStatus, "processed");
  assert.equal(refund.orderPath, orderRef.path);
  assert.equal(refund.status, "processed");
  assert.equal((await db.doc("products/p1").get()).data().stockCount, 5);
});
