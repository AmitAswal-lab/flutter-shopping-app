"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  createOrRecoverRefund,
  refundReceipt,
} = require("../razorpay_refund_service");

test("uses an existing matching refund instead of creating another one", async () => {
  const receipt = refundReceipt("order_123");
  let createCount = 0;
  const razorpay = {
    payments: {
      fetchMultipleRefund: async () => ({items: [{
        amount: 7999,
        created_at: 1_700_000_000,
        id: "rfnd_existing",
        notes: {cancellationToken: "token_123"},
        payment_id: "pay_123",
        receipt,
        status: "pending",
      }]}),
      refund: async () => {
        createCount += 1;
        return {};
      },
    },
  };

  const refund = await createOrRecoverRefund({
    amount: 7999,
    orderId: "order_123",
    paymentId: "pay_123",
    processingToken: "token_123",
    razorpay,
    userId: "alice",
  });

  assert.equal(createCount, 0);
  assert.equal(refund.id, "rfnd_existing");
  assert.equal(refund.status, "pending");
});

test("creates a full refund with a stable receipt", async () => {
  let request;
  const razorpay = {
    payments: {
      fetchMultipleRefund: async () => ({items: []}),
      refund: async (paymentId, input) => {
        request = {input, paymentId};
        return {
          amount: input.amount,
          created_at: 1_700_000_000,
          id: "rfnd_created",
          payment_id: paymentId,
          receipt: input.receipt,
          speed_processed: "normal",
          speed_requested: "normal",
          status: "processed",
        };
      },
    },
  };

  const refund = await createOrRecoverRefund({
    amount: 7999,
    orderId: "order_123",
    paymentId: "pay_123",
    processingToken: "token_123",
    razorpay,
    userId: "alice",
  });

  assert.equal(request.paymentId, "pay_123");
  assert.equal(request.input.amount, 7999);
  assert.equal(request.input.receipt, refundReceipt("order_123"));
  assert.equal(request.input.notes.appOrderId, "order_123");
  assert.equal(refund.status, "processed");
});
