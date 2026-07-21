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
  collectionGroup,
  deleteDoc,
  doc,
  getDocs,
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
  const alice = verifiedFirestore("alice");
  const bob = verifiedFirestore("bob");
  const profile = doc(alice, "users/alice");

  await assertSucceeds(
    setDoc(profile, {
      displayName: "Alice",
      deliveryAddress: "123 Test Street",
      updatedAt: serverTimestamp(),
    }),
  );
  await assertSucceeds(getDoc(profile));
  await assertFails(getDoc(doc(bob, "users/alice")));
  await assertFails(updateDoc(profile, { role: "admin" }));
  await assertFails(deleteDoc(profile));
});

test("cart items enforce ownership, identity, and quantity shape", async () => {
  const alice = verifiedFirestore("alice");
  const bob = verifiedFirestore("bob");
  const cartItem = doc(alice, "users/alice/cartItems/p1");

  await assertSucceeds(
    setDoc(cartItem, {
      name: "Headphones",
      priceCents: 7999,
      productId: "p1",
      quantity: 2,
      updatedAt: serverTimestamp(),
    }),
  );
  await assertSucceeds(
    updateDoc(cartItem, {
      quantity: 3,
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(getDoc(doc(bob, "users/alice/cartItems/p1")));
  await assertFails(
    setDoc(doc(alice, "users/alice/cartItems/p2"), {
      name: "Headphones",
      priceCents: 7999,
      productId: "p1",
      quantity: 1,
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(cartItem, {
      quantity: 0,
      updatedAt: serverTimestamp(),
    }),
  );
});

test("wishlist entries enforce owner and matching product ID", async () => {
  const alice = verifiedFirestore("alice");
  const bob = verifiedFirestore("bob");
  const wishlistItem = doc(alice, "users/alice/wishlistItems/p1");

  await assertSucceeds(
    setDoc(wishlistItem, {
      createdAt: serverTimestamp(),
      productId: "p1",
    }),
  );
  await assertFails(getDoc(doc(bob, "users/alice/wishlistItems/p1")));
  await assertFails(
    setDoc(doc(alice, "users/alice/wishlistItems/p2"), {
      createdAt: serverTimestamp(),
      productId: "p1",
    }),
  );
  await assertSucceeds(deleteDoc(wishlistItem));
});

test("delivery addresses are private and validate their saved shape", async () => {
  const alice = verifiedFirestore("alice");
  const bob = verifiedFirestore("bob");
  const address = doc(alice, "users/alice/deliveryAddresses/home");

  await assertSucceeds(
    setDoc(address, {
      address: "123 Test Street",
      createdAt: serverTimestamp(),
      fullName: "Alice",
      isDefault: true,
      label: "Home",
      phoneNumber: "1234567890",
      updatedAt: serverTimestamp(),
    }),
  );
  await assertSucceeds(getDoc(address));
  await assertFails(getDoc(doc(bob, "users/alice/deliveryAddresses/home")));
  await assertFails(updateDoc(address, { address: "No" }));
});

test("orders are readable by their owner or an administrator and backend-write-only", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users/alice/orders/order_123"), {
      status: "paid",
    });
    await setDoc(doc(context.firestore(), "admins/catalog-admin"), {
      role: "catalogAdmin",
    });
  });

  const alice = verifiedFirestore("alice");
  const bob = verifiedFirestore("bob");
  const admin = verifiedFirestore("catalog-admin");
  const order = doc(alice, "users/alice/orders/order_123");

  await assertSucceeds(getDoc(order));
  await assertFails(getDoc(doc(bob, "users/alice/orders/order_123")));
  await assertSucceeds(getDoc(doc(admin, "users/alice/orders/order_123")));
  await assertSucceeds(getDocs(collectionGroup(admin, "orders")));
  await assertFails(updateDoc(order, { status: "delivered" }));
  await assertFails(
    updateDoc(doc(admin, "users/alice/orders/order_123"), {
      status: "delivered",
    }),
  );
  await assertFails(deleteDoc(order));
});

test("device registrations enforce ownership and immutable creation time", async () => {
  const alice = verifiedFirestore("alice");
  const bob = verifiedFirestore("bob");
  const registration = doc(alice, "users/alice/deviceRegistrations/device_1");

  await assertSucceeds(
    setDoc(registration, {
      createdAt: serverTimestamp(),
      platform: "android",
      token: "valid-token",
      updatedAt: serverTimestamp(),
    }),
  );
  await assertSucceeds(
    updateDoc(registration, {
      token: "refreshed-token",
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    getDoc(doc(bob, "users/alice/deviceRegistrations/device_1")),
  );
  await assertFails(
    updateDoc(registration, {
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    setDoc(doc(alice, "users/alice/deviceRegistrations/device_2"), {
      createdAt: serverTimestamp(),
      platform: "desktop",
      token: "valid-token",
      updatedAt: serverTimestamp(),
    }),
  );
  await assertSucceeds(deleteDoc(registration));
});

test("products are authenticated-readable and backend-write-only", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "products/p1"), {
      name: "Headphones",
    });
  });

  const alice = verifiedFirestore("alice");
  const anonymous = environment.unauthenticatedContext().firestore();
  const product = doc(alice, "products/p1");

  await assertSucceeds(getDoc(product));
  await assertFails(getDoc(doc(anonymous, "products/p1")));
  await assertFails(updateDoc(product, { priceCents: 1 }));
});

test("users can check only their own administrator record", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "admins/alice"), {
      createdAt: serverTimestamp(),
    });
  });

  const alice = verifiedFirestore("alice");
  const bob = verifiedFirestore("bob");

  await assertSucceeds(getDoc(doc(alice, "admins/alice")));
  await assertFails(getDoc(doc(bob, "admins/alice")));
  await assertFails(setDoc(doc(alice, "admins/alice"), { role: "admin" }));
});

test("reviews are authenticated-readable and backend-write-only", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "products/p1/reviews/alice"), {
      comment: "Excellent product.",
      rating: 5,
      userId: "alice",
    });
  });

  const alice = verifiedFirestore("alice");
  const anonymous = environment.unauthenticatedContext().firestore();
  const review = doc(alice, "products/p1/reviews/alice");

  await assertSucceeds(getDoc(review));
  await assertFails(getDoc(doc(anonymous, "products/p1/reviews/alice")));
  await assertFails(updateDoc(review, { rating: 1 }));
  await assertFails(deleteDoc(review));
});

test("unverified users cannot access customer-owned data", async () => {
  const unverified = environment.authenticatedContext("alice", {
    email_verified: false,
  }).firestore();

  await assertFails(
    setDoc(doc(unverified, "users/alice"), {
      displayName: "Alice",
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(getDoc(doc(unverified, "users/alice")));
  await assertFails(
    setDoc(doc(unverified, "users/alice/cartItems/p1"), {
      name: "Headphones",
      priceCents: 7999,
      productId: "p1",
      quantity: 1,
      updatedAt: serverTimestamp(),
    }),
  );
});

function verifiedFirestore(userId) {
  return environment.authenticatedContext(userId, {
    email_verified: true,
  }).firestore();
}
