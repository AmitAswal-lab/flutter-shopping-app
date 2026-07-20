# MVP Launch Validation

## Purpose

The implemented customer MVP supports verified email/password accounts,
catalog browsing, cart and wishlist persistence, Razorpay Test Mode checkout,
order history and cancellation/refunds, notifications, reviews, delivery
addresses, and a separate admin web portal.

This checklist records the manual checks that cannot be proved by unit tests.
It is intended for the deployed Firebase **test** project. Do not introduce
Razorpay Live Mode or production credentials as part of MVP validation.

## Prerequisites

- The current Firestore rules and Cloud Functions are deployed to the intended
  Firebase test project.
- Razorpay Test Mode secrets and the webhook secret are configured in Firebase
  Secret Manager; no secret is stored in the app or repository.
- The Razorpay dashboard webhook is configured for the deployed
  `razorpayWebhook` endpoint and subscribed to the events in
  [Razorpay Webhooks](razorpay_webhooks.md).
- An admin user has an `admins/{uid}` Firestore document and the catalog
  contains at least one active, in-stock product.
- Use an accessible email inbox and a physical iOS device or iOS simulator.
  Android validation requires Firebase configuration whose Android package name
  matches the app's application ID.

## Automated Baseline

Run these checks before manual validation:

```bash
flutter analyze
flutter test
cd functions && npm run check && npm test
git diff --check
```

Record the command output or CI run with the validation evidence.

## Customer Account Flow

1. Create an account with a new accessible email address.
2. Confirm the email-verification screen, not the shopping shell, opens.
3. Confirm the verification email arrives; also try resend once if delivery is
   not immediate.
4. Open the link from the email, return to the app, and select **I have
   verified my email**.
5. Confirm the normal shopping shell opens; sign out and sign in again to
   confirm verified access persists.
6. Request a password reset for a registered address and an unregistered
   address. Both must display the same neutral response; only the registered
   address should receive an email.
7. From Account Security, change the password using the correct current
   password. Confirm a wrong current password is rejected.
8. In a separate disposable account, confirm account deletion works before
   verification and removes access to that account.

## Customer Shopping Flow

1. Browse, search, filter, and open a product detail page.
2. Add an in-stock product to the cart, change its quantity within stock, add
   it to the wishlist, and confirm cart/wishlist persistence after relaunch.
3. Create or select a delivery address, then start checkout.
4. Complete a Razorpay **Test Mode** payment. Confirm the order shows as paid
   with the expected items, price, delivery address, and timeline.
5. Start a second checkout and cancel or fail the Razorpay payment. Confirm
   its reservation/order state is resolved correctly and the stock is restored.
6. Cancel an eligible paid order. Confirm the refund state appears in the app
   and is later updated from the Razorpay event.
7. Submit, edit, and delete one product review. Confirm the displayed rating
   aggregate remains consistent.
8. Confirm an order notification opens the relevant order when tapped.

## Webhook and Admin Checks

1. In the Razorpay Test Mode dashboard, confirm webhook deliveries return HTTP
   200 for payment and refund events.
2. In Firestore, confirm the matching order and refund fields are updated and
   a completed event record exists in `razorpayWebhookEvents`.
3. Send a duplicate delivery from Razorpay, if available, and confirm it does
   not repeat a payment or refund operation.
4. Sign in to the admin web portal. Create or edit a product, update stock,
   archive/unarchive it, and confirm the customer catalog reflects the allowed
   changes.
5. Advance one order through the admin fulfilment workflow and confirm the
   customer order timeline reflects the update.

## Exit Criteria

The MVP is ready for an internal test milestone when all applicable automated
checks and manual scenarios pass, the test evidence is recorded, and no
customer data can be accessed before email verification. Android distribution
is out of scope until its Firebase package configuration and release signing
are completed.

## Not a Public-Release Checklist

Crash reporting, Firebase App Check, CI, separate development/production
projects, privacy and refund policies, data retention, credential rotation,
and load testing are public-release hardening work. Track their status in
[Security and Testing](security_and_testing.md).

## Validation Evidence

### Completed on 2026-07-20

- The Razorpay Test Mode dashboard was accessible without completing KYC.
- The deployed `razorpayWebhook` endpoint was enabled in Test Mode with all
  required events: `payment.captured`, `payment.failed`, `refund.created`,
  `refund.processed`, and `refund.failed`.
- Test Mode payment evidence showed captured payments and a processed refund.
- Deployed Cloud Function logs confirmed successful webhook reconciliation for
  `payment.captured`, an idempotent repeated `payment.captured` delivery,
  `refund.created`, and `refund.processed`.
- The admin portal loaded the catalog and paid-order queue. One disposable test
  order was advanced through Paid, Preparing, Shipped, and Delivered, then
  appeared in the Delivered queue.
- A customer checkout was exited from Razorpay Test Mode. The app recorded a
  **Payment failed** order, released the reservation, cleared the checkout
  cart, and restored Wireless Headphones stock from the reserved quantity back
  to 14.
- Order history was verified after deploying the required `orders.createdAt`
  descending collection index. The failed order and its no-reservation state
  loaded correctly in both the list and detail views.
- On a physical Android device, a Preparing notification was delivered for a
  paid Test Mode order. Tapping it opened the matching order detail screen and
  showed the Preparing timeline state.
- The revised Shipped notification was also verified on Android with
  customer-facing product text: “Mini Speaker is on its way.” The order ID
  remained in the notification payload for deep linking rather than being
  shown to the customer.

### Remaining manual checks

None for the internal MVP test milestone.
