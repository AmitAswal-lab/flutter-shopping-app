# Shopping Admin

Separate Flutter web admin portal for managing the Shopping App product catalog.

## What It Manages

- Product name, brand, description, category, price, MRP, stock, and sort order
- Product image uploads to Firebase Storage
- Product visibility with active/archive status

Review totals and ratings are displayed as read-only data because customer reviews own those aggregates.

## Admin Access

The admin app uses Firebase email/password sign-in, then checks Firestore for:

```text
admins/{uid}
```

Create that document manually in Firebase Console for each admin user. The document can be empty.

## Run Locally

```bash
cd admin_app
flutter run -d chrome
```

## Build For Hosting

```bash
cd admin_app
flutter build web
```

The root Firebase hosting config serves `admin_app/build/web`.
