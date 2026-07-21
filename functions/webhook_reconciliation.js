"use strict";

const {FieldValue} = require("firebase-admin/firestore");

const {
  finalizeOrderCancellation,
} = require("./order_cancellation_transaction");
const {createOrRecoverRefund} = require("./razorpay_refund_service");
const {applyRefundStatus} = require("./refund_tracking");

const PENDING_PAYMENT = "pendingPayment";
const RELEASED_UNPAID_STATUSES = new Set([
  "cancelled",
  "expired",
  "paymentFailed",
]);

async function reconcileRazorpayWebhook({db, event, eventId, razorpay}) {
  const eventRef = db.collection("razorpayWebhookEvents").doc(eventId);
  const shouldProcess = await registerWebhookEvent({event, eventRef});
  if (!shouldProcess) {
    return {action: "duplicate"};
  }

  try {
    const result = await reconcileEvent({db, event, razorpay});
    await eventRef.set({
      action: result.action,
      completedAt: FieldValue.serverTimestamp(),
      lastError: FieldValue.delete(),
      state: "completed",
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return result;
  } catch (error) {
    await eventRef.set({
      lastError: error instanceof Error ? error.message.slice(0, 500) :
        "Unknown webhook reconciliation error.",
      state: "failed",
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    throw error;
  }
}

async function registerWebhookEvent({event, eventRef}) {
  return eventRef.firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(eventRef);
    if (snapshot.exists && snapshot.data().state === "completed") {
      return false;
    }

    if (snapshot.exists) {
      transaction.update(eventRef, {
        attempts: FieldValue.increment(1),
        eventName: event.eventName,
        kind: event.kind,
        state: "processing",
        updatedAt: FieldValue.serverTimestamp(),
      });
    } else {
      transaction.create(eventRef, {
        attempts: 1,
        eventName: event.eventName,
        firstReceivedAt: FieldValue.serverTimestamp(),
        kind: event.kind,
        state: "processing",
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    return true;
  });
}

async function reconcileEvent({db, event, razorpay}) {
  switch (event.kind) {
    case "paymentCaptured":
      return reconcileCapturedPayment({db, event, razorpay});
    case "paymentFailed":
      return reconcileFailedPayment({db, event});
    case "refund":
      return reconcileRefund({db, event});
    default:
      return {action: "ignored"};
  }
}

async function reconcileCapturedPayment({db, event, razorpay}) {
  const orderRef = await orderReferenceForRazorpayOrder({
    db,
    razorpayOrderId: event.razorpayOrderId,
  });
  if (orderRef == null) return {action: "unmatchedPayment"};

  const result = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(orderRef);
    if (!snapshot.exists) return {action: "unmatchedPayment"};

    const order = snapshot.data();
    const invalidReason = invalidPaymentMatch({event, order});
    if (invalidReason != null) {
      return {action: invalidReason};
    }

    if (order.status === PENDING_PAYMENT) {
      transaction.update(orderRef, {
        paidAt: FieldValue.serverTimestamp(),
        paymentCapturedAt: FieldValue.serverTimestamp(),
        paymentProvider: "razorpay",
        razorpayPaymentId: event.razorpayPaymentId,
        razorpayPaymentStatus: "captured",
        status: "paid",
        updatedAt: FieldValue.serverTimestamp(),
      });
      return {action: "paymentCaptured", orderPath: orderRef.path};
    }

    if (order.status === "paid" &&
      (!order.razorpayPaymentId ||
        order.razorpayPaymentId === event.razorpayPaymentId)) {
      transaction.update(orderRef, {
        paymentCapturedAt: order.paymentCapturedAt ||
          FieldValue.serverTimestamp(),
        razorpayPaymentId: event.razorpayPaymentId,
        razorpayPaymentStatus: "captured",
        updatedAt: FieldValue.serverTimestamp(),
      });
      return {action: "paymentAlreadyCaptured", orderPath: orderRef.path};
    }

    const lateRefund = latePaymentRefundClaim({event, order});
    if (lateRefund != null) {
      if (lateRefund.isNew) {
        transaction.update(orderRef, {
          cancellationPreviousStatus: lateRefund.previousStatus,
          cancellationProcessingStartedAt: FieldValue.serverTimestamp(),
          cancellationProcessingToken: lateRefund.processingToken,
          cancellationReason: "latePaymentCaptured",
          cancellationRequestedAt: FieldValue.serverTimestamp(),
          cancellationRequestedBy: "system",
          paidAt: FieldValue.serverTimestamp(),
          paymentCapturedAt: FieldValue.serverTimestamp(),
          paymentProvider: "razorpay",
          razorpayPaymentId: event.razorpayPaymentId,
          razorpayPaymentStatus: "captured",
          refundStatus: "initiating",
          status: "cancellationPending",
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      return {
        action: "latePaymentRefundRequired",
        amount: order.totalPriceCents,
        orderId: orderRef.id,
        orderPath: orderRef.path,
        paymentId: event.razorpayPaymentId,
        processingToken: lateRefund.processingToken,
        userId: orderRef.parent.parent.id,
      };
    }

    return {action: "paymentIgnoredForOrderStatus", orderPath: orderRef.path};
  });

  if (result.action !== "latePaymentRefundRequired") return result;
  if (razorpay == null) {
    throw new Error("Razorpay is required to refund a late captured payment.");
  }

  const refund = await createOrRecoverRefund({
    amount: result.amount,
    orderId: result.orderId,
    paymentId: result.paymentId,
    processingToken: result.processingToken,
    razorpay,
    userId: result.userId,
  });
  await finalizeOrderCancellation({
    db,
    orderRef: db.doc(result.orderPath),
    processingToken: result.processingToken,
    refund,
    userId: result.userId,
  });

  return {
    action: `latePaymentRefund${capitalize(refund.status)}`,
    orderPath: result.orderPath,
  };
}

function latePaymentRefundClaim({event, order}) {
  const processingToken = order.cancellationProcessingToken;
  const resumesLateRefund =
    order.status === "cancellationPending" &&
    order.cancellationReason === "latePaymentCaptured" &&
    order.razorpayPaymentId === event.razorpayPaymentId &&
    typeof processingToken === "string" &&
    processingToken.length > 0;
  if (resumesLateRefund) {
    return {
      isNew: false,
      previousStatus: order.cancellationPreviousStatus,
      processingToken,
    };
  }

  const isReleasedUnpaidOrder =
    RELEASED_UNPAID_STATUSES.has(order.status) &&
    order.stockRestored === true &&
    order.paidAt == null &&
    !order.razorpayPaymentId;
  if (!isReleasedUnpaidOrder) return null;

  return {
    isNew: true,
    previousStatus: order.status,
    processingToken: `late-payment-${event.razorpayPaymentId}`,
  };
}

async function reconcileFailedPayment({db, event}) {
  const orderRef = await orderReferenceForRazorpayOrder({
    db,
    razorpayOrderId: event.razorpayOrderId,
  });
  if (orderRef == null) return {action: "unmatchedPayment"};

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(orderRef);
    if (!snapshot.exists) return {action: "unmatchedPayment"};

    const order = snapshot.data();
    const invalidReason = invalidPaymentMatch({event, order});
    if (invalidReason != null) return {action: invalidReason};
    if (order.status !== PENDING_PAYMENT) {
      return {action: "paymentIgnoredForOrderStatus", orderPath: orderRef.path};
    }

    transaction.update(orderRef, {
      lastRazorpayPaymentFailureCode: event.failureCode,
      lastRazorpayPaymentFailureMessage: event.failureReason,
      lastRazorpayPaymentFailureAt: FieldValue.serverTimestamp(),
      lastRazorpayPaymentFailureId: event.razorpayPaymentId,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {action: "paymentFailureRecorded", orderPath: orderRef.path};
  });
}

async function reconcileRefund({db, event}) {
  try {
    const refund = await applyRefundStatus({db, gatewayRefund: event});
    return {action: `refund${capitalize(refund.status)}`};
  } catch (error) {
    if (error instanceof Error &&
      error.message.startsWith("Refund tracking document ")) {
      return {action: "unmatchedRefund"};
    }
    throw error;
  }
}

async function orderReferenceForRazorpayOrder({db, razorpayOrderId}) {
  const orders = await db
    .collectionGroup("orders")
    .where("razorpayOrderId", "==", razorpayOrderId)
    .limit(2)
    .get();
  return orders.size === 1 ? orders.docs[0].ref : null;
}

function invalidPaymentMatch({event, order}) {
  if (order.razorpayOrderId !== event.razorpayOrderId) {
    return "paymentOrderMismatch";
  }
  if (order.paymentProvider && order.paymentProvider !== "razorpay") {
    return "paymentProviderMismatch";
  }
  if (order.totalPriceCents !== event.amount || event.currency !== "INR") {
    return "paymentAmountMismatch";
  }
  if (order.razorpayPaymentId &&
    order.razorpayPaymentId !== event.razorpayPaymentId &&
    order.status === "paid") {
    return "paymentIdMismatch";
  }
  return null;
}

function capitalize(value) {
  return value.charAt(0).toUpperCase() + value.slice(1);
}

module.exports = {
  invalidPaymentMatch,
  latePaymentRefundClaim,
  reconcileRazorpayWebhook,
};
