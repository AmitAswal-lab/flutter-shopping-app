"use strict";

const {FieldValue} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");

const {removeReview} = require("./review_transaction");

const TERMINAL_ORDER_STATUSES = new Set([
  "cancelled",
  "delivered",
  "expired",
  "paymentFailed",
]);
const RESOLVED_REFUND_STATUSES = new Set([
  "notRequired",
  "processed",
]);
const MAX_RECENT_AUTH_AGE_MILLIS = 5 * 60 * 1000;
const WRITE_BATCH_SIZE = 400;

function accountDeletionBlockReason(orders) {
  for (const order of orders) {
    if (!TERMINAL_ORDER_STATUSES.has(order.status)) {
      return "Finish or cancel active orders before deleting your account.";
    }

    const refundStatus = order.refundStatus || "notRequired";
    if (!RESOLVED_REFUND_STATUSES.has(refundStatus)) {
      return "Wait for pending refunds to finish before deleting your account.";
    }
  }
  return null;
}

function isRecentAuthentication(
  authTimeSeconds,
  {
    maxAgeMillis = MAX_RECENT_AUTH_AGE_MILLIS,
    nowMillis = Date.now(),
  } = {},
) {
  if (typeof authTimeSeconds !== "number" || !Number.isFinite(authTimeSeconds)) {
    return false;
  }

  const authTimeMillis = authTimeSeconds * 1000;
  const ageMillis = nowMillis - authTimeMillis;
  return ageMillis >= 0 && ageMillis <= maxAgeMillis;
}

async function deleteCustomerFirestoreData({db, userId}) {
  const userRef = db.collection("users").doc(userId);
  let orderSnapshots = await userRef.collection("orders").get();
  assertOrdersCanBeRetained(orderSnapshots.docs);

  await userRef.set({
    accountDeletionPending: true,
    accountDeletionStartedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  orderSnapshots = await userRef.collection("orders").get();
  try {
    assertOrdersCanBeRetained(orderSnapshots.docs);
  } catch (error) {
    await userRef.set({
      accountDeletionPending: FieldValue.delete(),
      accountDeletionStartedAt: FieldValue.delete(),
    }, {merge: true});
    throw error;
  }

  const reviewSnapshots = await db
    .collectionGroup("reviews")
    .where("userId", "==", userId)
    .get();
  for (const review of reviewSnapshots.docs) {
    const productId = review.ref.parent.parent.id;
    try {
      await removeReview({db, productId, userId});
    } catch (error) {
      if (error instanceof HttpsError && error.code === "not-found") {
        await review.ref.delete();
      } else {
        throw error;
      }
    }
  }

  const subcollections = await userRef.listCollections();
  for (const collection of subcollections) {
    if (collection.id !== "orders") await db.recursiveDelete(collection);
  }

  const refundSnapshots = await db
    .collection("refunds")
    .where("userId", "==", userId)
    .get();
  await anonymizeRetainedRecords({
    db,
    orders: orderSnapshots.docs,
    refunds: refundSnapshots.docs,
    userId,
  });

  await userRef.set({
    accountDeleted: true,
    accountDeletedAt: FieldValue.serverTimestamp(),
  });

  return {
    removedReviewCount: reviewSnapshots.size,
    retainedOrderCount: orderSnapshots.size,
  };
}

function assertOrdersCanBeRetained(orderDocuments) {
  const reason = accountDeletionBlockReason(
    orderDocuments.map((document) => document.data()),
  );
  if (reason != null) throw new HttpsError("failed-precondition", reason);
}

async function anonymizeRetainedRecords({db, orders, refunds, userId}) {
  const writes = [
    ...orders.map((order) => ({
      ref: order.ref,
      updates: anonymizedOrderFields(order.data(), userId),
    })),
    ...refunds.map((refund) => ({
      ref: refund.ref,
      updates: {
        accountOwnerDeletedAt: FieldValue.serverTimestamp(),
        userId: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      },
    })),
  ];

  for (let offset = 0; offset < writes.length; offset += WRITE_BATCH_SIZE) {
    const batch = db.batch();
    for (const write of writes.slice(offset, offset + WRITE_BATCH_SIZE)) {
      batch.update(write.ref, write.updates);
    }
    await batch.commit();
  }
}

function anonymizedOrderFields(order, userId) {
  const fields = {
    accountOwnerDeletedAt: FieldValue.serverTimestamp(),
    customerName: "Deleted customer",
    deliveryAddress: FieldValue.delete(),
    deliveryAddressId: FieldValue.delete(),
    deliveryPhoneNumber: FieldValue.delete(),
    deliveryRecipient: FieldValue.delete(),
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (order.cancelledBy === userId) fields.cancelledBy = FieldValue.delete();
  if (order.cancellationRequestedBy === userId) {
    fields.cancellationRequestedBy = FieldValue.delete();
  }
  return fields;
}

module.exports = {
  accountDeletionBlockReason,
  deleteCustomerFirestoreData,
  isRecentAuthentication,
};
