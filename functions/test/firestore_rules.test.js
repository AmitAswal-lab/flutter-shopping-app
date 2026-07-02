"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} = require("firebase/firestore");

const PROJECT_ID = "shopping-app-rules-test";
let environment;

test.before(async () => {
  environment = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(
        path.resolve(__dirname, "../../firestore.rules"),
        "utf8",
      ),
    },
  });
});

test.beforeEach(async () => {
  await environment.clearFirestore();
});

test.after(async () => {
  await environment.cleanup();
});

test("users can read and update only their valid profile", async () => {
  const alice = environment.authenticatedContext("alice").firestore();
  const bob = environment.authenticatedContext("bob").firestore();
  const profile = doc(alice, "users/alice");

  await assertSucceeds(setDoc(profile, {
    displayName: "Alice",
    deliveryAddress: "123 Test Street",
    updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(getDoc(profile));
  await assertFails(getDoc(doc(bob, "users/alice")));
  await assertFails(updateDoc(profile, {role: "admin"}));
  await assertFails(deleteDoc(profile));
});

test("cart items enforce ownership, identity, and quantity shape", async () => {
  const alice = environment.authenticatedContext("alice").firestore();
  const bob = environment.authenticatedContext("bob").firestore();
  const cartItem = doc(alice, "users/alice/cartItems/p1");

  await assertSucceeds(setDoc(cartItem, {
    name: "Headphones",
    priceCents: 7999,
    productId: "p1",
    quantity: 2,
    updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(cartItem, {
    quantity: 3,
    updatedAt: serverTimestamp(),
  }));
  await assertFails(getDoc(doc(bob, "users/alice/cartItems/p1")));
  await assertFails(setDoc(doc(alice, "users/alice/cartItems/p2"), {
    name: "Headphones",
    priceCents: 7999,
    productId: "p1",
    quantity: 1,
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(cartItem, {
    quantity: 0,
    updatedAt: serverTimestamp(),
  }));
});

test("wishlist entries enforce owner and matching product ID", async () => {
  const alice = environment.authenticatedContext("alice").firestore();
  const bob = environment.authenticatedContext("bob").firestore();
  const wishlistItem = doc(alice, "users/alice/wishlistItems/p1");

  await assertSucceeds(setDoc(wishlistItem, {
    createdAt: serverTimestamp(),
    productId: "p1",
  }));
  await assertFails(getDoc(doc(bob, "users/alice/wishlistItems/p1")));
  await assertFails(setDoc(doc(alice, "users/alice/wishlistItems/p2"), {
    createdAt: serverTimestamp(),
    productId: "p1",
  }));
  await assertSucceeds(deleteDoc(wishlistItem));
});

test("orders are owner-readable but remain backend-write-only", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users/alice/orders/order_123"), {
      status: "paid",
    });
  });

  const alice = environment.authenticatedContext("alice").firestore();
  const bob = environment.authenticatedContext("bob").firestore();
  const order = doc(alice, "users/alice/orders/order_123");

  await assertSucceeds(getDoc(order));
  await assertFails(getDoc(doc(bob, "users/alice/orders/order_123")));
  await assertFails(updateDoc(order, {status: "delivered"}));
  await assertFails(deleteDoc(order));
});

test("products are authenticated-readable and backend-write-only", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "products/p1"), {
      name: "Headphones",
    });
  });

  const alice = environment.authenticatedContext("alice").firestore();
  const anonymous = environment.unauthenticatedContext().firestore();
  const product = doc(alice, "products/p1");

  await assertSucceeds(getDoc(product));
  await assertFails(getDoc(doc(anonymous, "products/p1")));
  await assertFails(updateDoc(product, {priceCents: 1}));
});

test("reviews are authenticated-readable and backend-write-only", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "products/p1/reviews/alice"), {
      comment: "Excellent product.",
      rating: 5,
      userId: "alice",
    });
  });

  const alice = environment.authenticatedContext("alice").firestore();
  const anonymous = environment.unauthenticatedContext().firestore();
  const review = doc(alice, "products/p1/reviews/alice");

  await assertSucceeds(getDoc(review));
  await assertFails(getDoc(doc(anonymous, "products/p1/reviews/alice")));
  await assertFails(updateDoc(review, {rating: 1}));
  await assertFails(deleteDoc(review));
});
