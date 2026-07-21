"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");

const PROJECT_ID = "shopping-app-account-deletion-rules-test";
let environment;

test.before(async () => {
  environment = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
});

test.beforeEach(async () => {
  await environment.clearFirestore();
});

test.after(async () => {
  await environment.cleanup();
});

test("deleted accounts cannot read or recreate retained user data", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc("users/alice").set({accountDeleted: true});
    await db.doc("users/alice/orders/order_123").set({status: "delivered"});
    await db.doc("admins/admin").set({role: "catalog"});
  });

  const customerDb = environment.authenticatedContext("alice", {
    email_verified: true,
  }).firestore();
  const adminDb = environment.authenticatedContext("admin", {
    email_verified: true,
  }).firestore();

  await assertFails(customerDb.doc("users/alice").get());
  await assertFails(customerDb.doc("users/alice").set({displayName: "Alice"}));
  await assertFails(customerDb.doc("users/alice/cartItems/p1").set({quantity: 1}));
  await assertFails(customerDb.doc("users/alice/orders/order_123").get());
  await assertSucceeds(adminDb.doc("users/alice/orders/order_123").get());
});

test("pending deletion closes user access before cleanup starts", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("users/alice").set({
      accountDeletionPending: true,
      displayName: "Alice",
    });
  });

  const customerDb = environment.authenticatedContext("alice", {
    email_verified: true,
  }).firestore();
  await assertFails(customerDb.doc("users/alice").get());
  await assertFails(customerDb.doc("users/alice/wishlistItems/p1").set({}));
});
