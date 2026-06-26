# Shopping App

A Flutter shopping app built as a learning project for app development, UI structure, navigation, and state management with the `provider` package.

The goal of this project is to build a realistic shopping flow step by step while keeping the codebase lean enough to understand clearly.

## Current Progress

The app currently includes:

- Product browsing with searchable, filterable product cards
- Expanded local product catalog with brand, rating, stock, and description data
- Auth-gated main app with bottom navigation for Shop, Wishlist, Orders, Cart, and Account
- Product detail pages with quantity selection and add-to-cart behavior
- Cart and checkout flow with order confirmation
- Wishlist/favorites experience
- User-scoped cart, wishlist, and order history backed by Cloud Firestore
- Separate sign-in/create-account flow and signed-in account profile UI
- Centralized Material theme foundation
- Local product and screenshot assets

## Learning Focus

This project is currently focused on understanding state management with Provider.

Current state-management decisions:

- `Cart` is shared app state and is exposed with `ChangeNotifierProvider`.
- `ProductFilter` is shared catalog state and is exposed with `ChangeNotifierProvider`.
- `Wishlist` is shared app state and is exposed with `ChangeNotifierProvider`.
- `OrderHistory` is shared app state and is exposed with `ChangeNotifierProvider`.
- `AuthController` owns Firebase auth/profile state and is exposed with `ChangeNotifierProvider`.
- `AuthGate` shows the auth flow before the main shopping shell when no user is signed in.
- Cart, wishlist, and order history bind to the signed-in user's Firebase UID.
- Cart mutations live in `Cart`, such as `add`, `remove`, `setQuantity`, and `clear`.
- Search and category mutations live in `ProductFilter`, such as `setQuery`, `setCategory`, and `clear`.
- Favorite mutations live in `Wishlist`, such as `toggle`, `remove`, and `clear`.
- Checkout creates an order snapshot before clearing the cart so order history keeps its own copy of purchased items.
- Wishlist stores product IDs instead of full product objects so product details still come from the catalog.
- Cart, wishlist, and order history are persisted under the signed-in user in Firestore.
- Temporary screen state stays local to the screen.
- The search text controller stays local to the search field because it is a UI controller, not app data.
- Product detail quantity is local state because it only matters before the item is added to the cart.
- Checkout form controllers are local state because they only belong to the checkout form.
- `context.read` is used for actions that update state.
- `context.select` is used when a widget only needs a specific value from Provider.
- `Consumer` is used when a larger section needs to rebuild from cart changes.

## Screenshots

Screenshots will be added as the app reaches meaningful feature milestones. Since the app is still in early development, screenshots will be used from this point forward to show how the app progresses over time.

Current milestone screenshots:

| Product Grid                                                                                                                 | Product Detail                                                                                                                 |
| ---------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| <img width="240" alt="Product grid" src="https://github.com/user-attachments/assets/579d8825-a399-4c3d-8f8b-2d50723952bd" /> | <img width="240" alt="Product detail" src="https://github.com/user-attachments/assets/ade50b95-8dfc-405c-8432-626e03cad177" /> |

| Cart                                                                                                                 | Checkout                                                                                                                 |
| -------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| <img width="240" alt="Cart" src="https://github.com/user-attachments/assets/70b41f3f-9f39-43d8-864e-26f831438534" /> | <img width="240" alt="Checkout" src="https://github.com/user-attachments/assets/a78966bd-c2e2-4fb4-97c5-004341afa679" /> |

| Order Success                                                                      |
| ---------------------------------------------------------------------------------- |
| <img width="240" alt="Order success" src="assets/screenshots/order_success.png" /> |

| Search and Filtering                                                                         | Wishlist                                                                 |
| -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| <img width="240" alt="Search and filtering" src="assets/screenshots/search_filtering.png" /> | <img width="240" alt="Wishlist" src="assets/screenshots/wishlist.png" /> |

| Product Detail Favorite                                                                                |
| ------------------------------------------------------------------------------------------------------ |
| <img width="240" alt="Product detail favorite" src="assets/screenshots/product_detail_favorite.png" /> |

| Order History                                                                      |
| ---------------------------------------------------------------------------------- |
| <img width="240" alt="Order history" src="assets/screenshots/order_history.png" /> |

| Clean Navigation                                                                         |
| ---------------------------------------------------------------------------------------- |
| <img width="240" alt="Clean navigation" src="assets/screenshots/clean_navigation.png" /> |

Suggested location for future screenshots:

```text
assets/screenshots/
```

## Project Structure

```text
lib/
  main.dart
  models/
    cart_item.dart
    order.dart
    product.dart
  providers/
    cart.dart
    auth_controller.dart
    order_history.dart
    product_filter.dart
    wishlist.dart
  screens/
    account_screen.dart
    auth_screen.dart
    cart_screen.dart
    checkout_screen.dart
    main_shell_screen.dart
    order_history_screen.dart
    order_success_screen.dart
    product_detail_screen.dart
    product_list_screen.dart
    wishlist_screen.dart
  theme/
    app_theme.dart
  utils/
    date_time_format.dart
    money.dart
  widgets/
    product_card.dart
    wishlist_icon_button.dart

assets/
  products/
  screenshots/
```

## Git Workflow

The project uses:

- `main` for meaningful stable updates
- `dev` for active development

Current development work is committed directly to `dev`. When `dev` reaches a meaningful upgrade point, it can be merged into `main`.

## Running The App

Install dependencies:

```bash
flutter pub get
```

Run on an iOS simulator:

```bash
flutter run
```

Analyze the project:

```bash
flutter analyze
```

## Firebase Setup

Firebase email/password authentication is wired in the app.
Cloud Firestore is used for user-scoped cart, wishlist, and order history data.

The iOS Firebase app is configured with:

```text
Bundle ID: com.example.shoppingApp
Config file: ios/Runner/GoogleService-Info.plist
```

Email/Password sign-in must be enabled in the Firebase Authentication console.
Cloud Firestore must also be enabled for the Firebase project.

User data is stored under:

```text
users/{uid}/cartItems/{productId}
users/{uid}/wishlistItems/{productId}
users/{uid}/orders/{orderId}
```

Android Firebase setup is not wired yet because the provided Android Firebase app uses:

```text
Package name: com.example.shoppingApp
```

The current Android application ID is `com.example.shopping_app`.
