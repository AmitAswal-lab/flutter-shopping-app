"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  accountDeletionBlockReason,
  isRecentAuthentication,
} = require("../account_deletion");

test("blocks deletion while orders or refunds are active", () => {
  assert.equal(
    accountDeletionBlockReason([{status: "processing"}]),
    "Finish or cancel active orders before deleting your account.",
  );
  assert.equal(
    accountDeletionBlockReason([{
      refundStatus: "pending",
      status: "cancelled",
    }]),
    "Wait for pending refunds to finish before deleting your account.",
  );
});

test("allows deletion when retained orders have no unfinished work", () => {
  assert.equal(accountDeletionBlockReason([]), null);
  assert.equal(
    accountDeletionBlockReason([
      {status: "delivered"},
      {refundStatus: "processed", status: "cancelled"},
      {status: "expired"},
    ]),
    null,
  );
});

test("requires authentication from the last five minutes", () => {
  const nowMillis = 1_800_000_000_000;

  assert.equal(isRecentAuthentication(1_799_999_880, {nowMillis}), true);
  assert.equal(isRecentAuthentication(1_799_999_699, {nowMillis}), false);
  assert.equal(isRecentAuthentication(null, {nowMillis}), false);
});
