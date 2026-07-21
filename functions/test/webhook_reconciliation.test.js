"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  invalidPaymentMatch,
  latePaymentRefundClaim,
} = require("../webhook_reconciliation");

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

test("claims a refund when payment is captured after inventory release", () => {
  for (const status of ["paymentFailed", "cancelled", "expired"]) {
    assert.deepEqual(
      latePaymentRefundClaim({
        event: validEvent,
        order: {
          ...validOrder,
          status,
          stockRestored: true,
        },
      }),
      {
        isNew: true,
        previousStatus: status,
        processingToken: "late-payment-pay_123",
      },
    );
  }
});

test("resumes an interrupted late-payment refund idempotently", () => {
  assert.deepEqual(
    latePaymentRefundClaim({
      event: validEvent,
      order: {
        ...validOrder,
        cancellationPreviousStatus: "expired",
        cancellationProcessingToken: "late-payment-pay_123",
        cancellationReason: "latePaymentCaptured",
        razorpayPaymentId: "pay_123",
        status: "cancellationPending",
      },
    }),
    {
      isNew: false,
      previousStatus: "expired",
      processingToken: "late-payment-pay_123",
    },
  );
});

test("does not refund a duplicate capture for a previously paid order", () => {
  assert.equal(
    latePaymentRefundClaim({
      event: validEvent,
      order: {
        ...validOrder,
        paidAt: {seconds: 1},
        razorpayPaymentId: "pay_123",
        status: "cancelled",
        stockRestored: true,
      },
    }),
    null,
  );
});
