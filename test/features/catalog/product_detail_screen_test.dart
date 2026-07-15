import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/core/theme/app_theme.dart';
import 'package:shopping_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:shopping_app/features/cart/presentation/controllers/cart.dart';
import 'package:shopping_app/features/catalog/domain/models/product.dart';
import 'package:shopping_app/features/catalog/presentation/controllers/product_catalog.dart';
import 'package:shopping_app/features/catalog/presentation/screens/product_detail_screen.dart';
import 'package:shopping_app/features/catalog/presentation/widgets/product_image.dart';
import 'package:shopping_app/features/reviews/presentation/controllers/product_reviews.dart';
import 'package:shopping_app/features/wishlist/presentation/controllers/wishlist.dart';

void main() {
  testWidgets('renders product details and reviews without build errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthController.unconfigured(null),
          ),
          ChangeNotifierProvider(create: (_) => Cart()),
          ChangeNotifierProvider(
            create: (_) => ProductCatalog(firestore: null),
          ),
          ChangeNotifierProvider(
            create: (_) => ProductReviews(firestore: null),
          ),
          ChangeNotifierProvider(create: (_) => Wishlist()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const ProductDetailScreen(product: _product),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bluetooth Speaker'), findsWidgets);
    expect(find.byType(ProductImage), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Reviews'), 300);
    expect(find.text('Reviews'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _product = Product(
  id: 'p3',
  brand: 'SoundLab',
  name: 'Bluetooth Speaker',
  description: 'Portable audio for everyday listening.',
  priceCents: 4999,
  listPriceCents: 7499,
  imageAsset: 'assets/products/bluetooth_speaker.png',
  category: ProductCategory.audio,
  rating: 4.3,
  reviewCount: 42,
  stockCount: 10,
);
