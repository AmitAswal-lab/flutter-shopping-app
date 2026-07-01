import 'package:flutter_test/flutter_test.dart';

import 'package:shopping_app/features/catalog/domain/models/product.dart';
import 'package:shopping_app/features/catalog/presentation/controllers/product_filter.dart';

void main() {
  group('ProductFilter', () {
    test('searches across category, brand, name, and description', () {
      final filter = ProductFilter();

      filter.setQuery('audio');
      expect(filter.applyTo(_products).map((product) => product.id), ['p1']);

      filter.setQuery('pulse');
      expect(filter.applyTo(_products).map((product) => product.id), ['p2']);

      filter.setQuery('workouts');
      expect(filter.applyTo(_products).map((product) => product.id), ['p2']);
    });

    test('combines search and category filters', () {
      final filter = ProductFilter()
        ..setQuery('daily')
        ..setCategory(ProductCategory.audio);

      expect(filter.applyTo(_products).map((product) => product.id), ['p1']);
    });

    test('clear restores the full catalog', () {
      final filter = ProductFilter()
        ..setQuery('watch')
        ..setCategory(ProductCategory.wearable);

      filter.clear();

      expect(filter.hasActiveFilters, isFalse);
      expect(filter.applyTo(_products), _products);
    });
  });
}

const _products = [
  Product(
    id: 'p1',
    brand: 'SoundLab',
    name: 'Wireless Headphones',
    description: 'Comfortable audio for daily listening.',
    priceCents: 7999,
    listPriceCents: 11999,
    imageAsset: 'assets/products/headphones.png',
    category: ProductCategory.audio,
    rating: 4.5,
    reviewCount: 100,
    stockCount: 10,
  ),
  Product(
    id: 'p2',
    brand: 'Pulse',
    name: 'Smart Watch',
    description: 'Track workouts and notifications.',
    priceCents: 12999,
    listPriceCents: 17999,
    imageAsset: 'assets/products/watch.png',
    category: ProductCategory.wearable,
    rating: 4.4,
    reviewCount: 80,
    stockCount: 8,
  ),
];
