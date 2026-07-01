# Security and Testing Report

## Purpose

This report records the production-hardening work performed after payments,
inventory reservation, and order lifecycle tracking were implemented.

The goal was not to claim that the learning project is production-ready. The
goal was to identify high-risk boundaries, test them realistically, tighten
access rules, and document the remaining work honestly.

## Test Layers

### Flutter domain and Provider tests

Run:

```bash
flutter test
```

Coverage currently includes:

- cart stock limits;
- payment and order-status mapping;
- order lifecycle progress and timestamps;
- product search and category filtering;
- local wishlist mutations and catalog resolution;
- local profile state.

These tests are fast and do not require Firebase.

### Backend logic tests

Run:

```bash
cd functions
npm test
```

Coverage includes:

- checkout input parsing;
- payment input validation;
- Razorpay signature verification;
- stored order-item validation;
- order lifecycle transitions.

### Firestore Emulator tests

Firestore Emulator requires Java. On this development machine, Android
Studio's bundled Java runtime can be used:

```bash
cd functions
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
PATH="$JAVA_HOME/bin:$PATH" \
npm run test:emulator
```

These tests run locally and do not read or modify production Firestore.

The emulator suite verifies:

- users can read only their own profile;
- profile writes accept only known profile fields;
- users cannot grant themselves roles or delete their profile document;
- cart and wishlist data is isolated by Firebase UID;
- cart quantities and document/product IDs are validated;
- customers cannot write orders or products;
- unauthenticated users cannot read products;
- repeated checkout IDs do not reserve stock twice;
- two concurrent buyers cannot reserve the same final stock unit.

## Firestore Rule Changes

The customer app may now write only the data it owns and understands:

```text
users/{uid}
users/{uid}/cartItems/{productId}
users/{uid}/wishlistItems/{productId}
```

Order and product writes remain blocked from client SDKs:

```text
users/{uid}/orders/{orderId}
products/{productId}
```

Trusted Cloud Functions use the Firebase Admin SDK for inventory, payment,
order, and lifecycle updates.

Rules validate field names, basic types, string lengths, quantities, document
identity, and server timestamps. These checks reduce malformed or unexpected
data. They do not make client-provided cart names or prices authoritative;
checkout still reads trusted price and stock values from product documents.

## Checkout Concurrency

The inventory reservation transaction was extracted into
`functions/checkout_transaction.js`. The deployed callable function and the
emulator test now execute the same transaction code.

The concurrency test creates one product with one unit of stock and two users
with that product in their carts. Both transactions start concurrently. The
test verifies:

- exactly one checkout succeeds;
- exactly one checkout fails;
- final stock is zero, never negative;
- exactly one order exists.

Firestore may retry a transaction when another transaction changes a document
it read. The losing transaction then observes zero stock and fails the existing
stock validation.

## Loading and Error States

Cart, Wishlist, and Orders now distinguish:

- initial loading;
- successful empty data;
- subscription failure;
- loaded content.

Retry actions restart their Firestore subscription. Cart also waits for the
catalog before deciding that persisted cart products are unavailable.

This prevents a common UI defect where an empty-state message briefly appears
while remote data is still loading.

## Razorpay Configuration

Razorpay secret keys must remain in Firebase Secret Manager. They must never be
stored in Flutter source, Git history, Firestore, screenshots, or documentation.

The Razorpay key ID is designed to be sent to the checkout client. The key
secret is backend-only and is used for signature verification.

The test secret previously shared during development should be rotated:

1. Generate a replacement Test Mode key pair in Razorpay.
2. Update `RAZORPAY_KEY_ID` and `RAZORPAY_KEY_SECRET` in Firebase Secret
   Manager.
3. Redeploy the Razorpay functions.
4. Revoke the old Razorpay key pair.
5. Run a successful test payment and a failed/cancelled payment.

Do not switch to Razorpay Live Mode until backend verification, business
onboarding, policies, and monitoring are ready.

## Dependency Audit

`npm audit --omit=dev` currently reports moderate transitive `uuid`
advisories through Google/Firebase dependencies. npm's automatic forced fix
suggests downgrading `firebase-admin` across a breaking major version, so that
forced fix was intentionally not applied.

The correct follow-up is to update Firebase packages when their compatible
dependency chain includes the patched package, then rerun backend and emulator
tests. A breaking forced downgrade would create more risk than it removes.

## Remaining Production Work

Before a real public release:

- rotate the exposed Razorpay Test Mode credentials;
- enable and enforce Firebase App Check for supported services;
- remove or strictly admin-gate the demo order lifecycle simulator;
- configure Crashlytics and backend error monitoring;
- add CI that runs Flutter, backend, and emulator tests;
- define data retention and account-deletion behavior;
- review privacy, refund, cancellation, and payment policies;
- load-test checkout and scheduled functions;
- test network loss and payment interruption on physical devices;
- configure separate Firebase projects for development and production.

