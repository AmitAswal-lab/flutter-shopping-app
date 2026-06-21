# Shopping App

A Flutter shopping app built as a learning project for app development, UI structure, navigation, and state management with the `provider` package.

The goal of this project is to build a realistic shopping flow step by step while keeping the codebase lean enough to understand clearly.

## Current Progress

The app currently includes:

- Product listing screen with a responsive product card grid
- Product search by product name or category
- Category filtering for products
- Local product image assets
- Product detail screen
- Wishlist/favorites screen
- Favorite toggles from product cards and product detail
- Quantity selector on the product detail screen
- Add-to-cart behavior from both the product list and product detail screens
- Cart badge with live item count
- Cart screen with quantity controls
- Cart total calculation
- Clear cart action
- Checkout screen with basic form validation
- In-memory order history screen
- Order placement flow that clears the cart
- Order success screen after checkout

## Learning Focus

This project is currently focused on understanding state management with Provider.

Current state-management decisions:

- `Cart` is shared app state and is exposed with `ChangeNotifierProvider`.
- `ProductFilter` is shared catalog state and is exposed with `ChangeNotifierProvider`.
- `Wishlist` is shared app state and is exposed with `ChangeNotifierProvider`.
- `OrderHistory` is shared app state and is exposed with `ChangeNotifierProvider`.
- Cart mutations live in `Cart`, such as `add`, `remove`, `setQuantity`, and `clear`.
- Search and category mutations live in `ProductFilter`, such as `setQuery`, `setCategory`, and `clear`.
- Favorite mutations live in `Wishlist`, such as `toggle`, `remove`, and `clear`.
- Checkout creates an order snapshot before clearing the cart so order history keeps its own copy of purchased items.
- Wishlist stores product IDs instead of full product objects so product details still come from the catalog.
- Order history is currently in-memory; persistence will be added later.
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

| Product Grid | Product Detail |
| --- | --- |
| <img width="240" alt="Product grid" src="https://github.com/user-attachments/assets/579d8825-a399-4c3d-8f8b-2d50723952bd" /> | <img width="240" alt="Product detail" src="https://github.com/user-attachments/assets/ade50b95-8dfc-405c-8432-626e03cad177" /> |

| Cart | Checkout |
| --- | --- |
| <img width="240" alt="Cart" src="https://github.com/user-attachments/assets/70b41f3f-9f39-43d8-864e-26f831438534" /> | <img width="240" alt="Checkout" src="https://github.com/user-attachments/assets/a78966bd-c2e2-4fb4-97c5-004341afa679" /> |

| Order Success |
| --- |
| <img width="240" alt="Order success" src="assets/screenshots/order_success.png" /> |

| Search and Filtering | Wishlist |
| --- | --- |
| <img width="240" alt="Search and filtering" src="assets/screenshots/search_filtering.png" /> | <img width="240" alt="Wishlist" src="assets/screenshots/wishlist.png" /> |

| Product Detail Favorite |
| --- |
| <img width="240" alt="Product detail favorite" src="assets/screenshots/product_detail_favorite.png" /> |

| Order History |
| --- |
| <img width="240" alt="Order history" src="assets/screenshots/order_history.png" /> |

Suggested location for future screenshots:

```text
assets/screenshots/
```

## Project Structure

```text
lib/
  main.dart
  models/
    cart.dart
    cart_item.dart
    order.dart
    order_history.dart
    product.dart
    product_filter.dart
    wishlist.dart
  screens/
    cart_screen.dart
    checkout_screen.dart
    order_history_screen.dart
    order_success_screen.dart
    product_detail_screen.dart
    product_list_screen.dart
    wishlist_screen.dart
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

## Roadmap

Planned next features:

- Add product sorting by price and name
- Move product data behind a repository class
- Add async product loading with loading, empty, and error states
- Persist the cart locally between app launches
- Improve checkout with phone number, delivery notes, and payment method selection
- Add stock quantity rules
- Add discount code logic
- Add a fake authentication flow
- Later, connect product data to an API or backend service

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
