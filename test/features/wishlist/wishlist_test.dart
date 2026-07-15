import 'package:flutter_test/flutter_test.dart';

import 'package:shopping_app/features/catalog/domain/models/product.dart';
import 'package:shopping_app/features/wishlist/presentation/controllers/wishlist.dart';

void main() {
  group('Wishlist', () {
    test('toggles, removes, and clears local favorites', () async {
      final wishlist = Wishlist();

      await wishlist.toggle('p1');
      expect(wishlist.isFavorite('p1'), isTrue);

      await wishlist.toggle('p1');
      expect(wishlist.isFavorite('p1'), isFalse);

      await wishlist.toggle('p1');
      await wishlist.remove('p1');
      expect(wishlist.isEmpty, isTrue);

      await wishlist.toggle('p1');
      await wishlist.toggle('p2');
      await wishlist.clear();
      expect(wishlist.isEmpty, isTrue);
    });

    test('resolves favorite IDs from the shared catalog', () async {
      final wishlist = Wishlist();
      await wishlist.toggle('p2');

      final favorites = wishlist.favoritesFrom(_products);

      expect(favorites.map((product) => product.id), ['p2']);
    });
  });
}

const _products = [
  Product(
    id: 'p1',
    brand: 'SoundLab',
    name: 'Headphones',
    description: 'Wireless headphones.',
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
    description: 'Fitness watch.',
    priceCents: 12999,
    listPriceCents: 17999,
    imageAsset: 'assets/products/watch.png',
    category: ProductCategory.wearable,
    rating: 4.4,
    reviewCount: 80,
    stockCount: 8,
  ),
];
