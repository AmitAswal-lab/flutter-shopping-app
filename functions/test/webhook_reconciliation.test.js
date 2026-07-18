"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {invalidPaymentMatch} = require("../webhook_reconciliation");

const validOrder = {
  paymentProvider: "razorpay",
  razorpayOrderId: "order_123",
  status: "pendingPayment",
  totalPriceCents: 4999,
};

const validEvent = {
  amount: 4999,
  currency: "INR",
  razorpayOrderId: "order_123",
  razorpayPaymentId: "pay_123",
};

test("accepts a matching captured Razorpay payment", () => {
  assert.equal(
    invalidPaymentMatch({event: validEvent, order: validOrder}),
    null,
  );
});

test("rejects Razorpay payments with an incorrect amount or payment ID", () => {
  assert.equal(
    invalidPaymentMatch({
      event: {...validEvent, amount: 5000},
      order: validOrder,
    }),
    "paymentAmountMismatch",
  );
  assert.equal(
    invalidPaymentMatch({
      event: validEvent,
      order: {
        ...validOrder,
        razorpayPaymentId: "pay_other",
        status: "paid",
      },
    }),
    "paymentIdMismatch",
  );
});
