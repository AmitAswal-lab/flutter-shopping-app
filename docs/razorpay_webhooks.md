# Razorpay Webhooks

The `razorpayWebhook` Firebase Function reconciles payment and refund events
from Razorpay with the matching Firestore order. It verifies Razorpay's HMAC
signature against the exact request body before changing any data.

## One-Time Setup

1. Create a strong webhook secret. Keep it private; it is not the Razorpay key
   secret.

   ```sh
   openssl rand -hex 32
   ```

2. Store the same value in Firebase Functions:

   ```sh
   firebase functions:secrets:set RAZORPAY_WEBHOOK_SECRET
   ```

3. Deploy the webhook function:

   ```sh
   firebase deploy --only functions:razorpayWebhook
   ```

4. In the Razorpay Test Mode dashboard, add a webhook with this URL:

   ```text
   https://us-central1-shopping-app-3caf5.cloudfunctions.net/razorpayWebhook
   ```

   Paste the same secret from step 1 and subscribe to:

   - `payment.captured`
   - `payment.failed`
   - `refund.created`
   - `refund.processed`
   - `refund.failed`

## Expected Behaviour

- `payment.captured` marks a matching `pendingPayment` order as `paid` and
  stores the Razorpay payment ID.
- `payment.failed` records diagnostic information but leaves the order pending
  so the customer can retry before its reservation expires.
- Refund events update the existing refund-tracking document and order status.
- Re-delivered webhook payloads are recorded in `razorpayWebhookEvents` and do
  not repeat the payment or refund operation.

## Manual Verification

1. Place an order with Razorpay Test Mode.
2. In Firestore, find the matching order under `users/{uid}/orders/{orderId}`.
   Confirm `status` is `paid`, `razorpayPaymentStatus` is `captured`, and
   `paymentCapturedAt` is populated.
3. Confirm a completed document exists in `razorpayWebhookEvents` and that the
   Razorpay dashboard's webhook delivery shows a `200` response.
4. Cancel that paid order. Confirm the Razorpay dashboard emits the refund
   event and the app displays the resulting refund status.
