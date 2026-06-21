import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/wishlist.dart';
import '../widgets/product_card.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isEmpty = context.select<Wishlist, bool>(
      (wishlist) => wishlist.isEmpty,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wishlist'),
        actions: [
          if (!isEmpty)
            TextButton(
              onPressed: context.read<Wishlist>().clear,
              child: const Text('Clear'),
            ),
        ],
      ),
      body: const _WishlistBody(),
    );
  }
}

class _WishlistBody extends StatelessWidget {
  const _WishlistBody();

  @override
  Widget build(BuildContext context) {
    final favoriteProducts = context.select<Wishlist, List<Product>>(
      (wishlist) => wishlist.favoritesFrom(kProducts),
    );

    if (favoriteProducts.isEmpty) {
      return const _EmptyWishlist();
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: favoriteProducts.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) {
        return ProductCard(product: favoriteProducts[index]);
      },
    );
  }
}

class _EmptyWishlist extends StatelessWidget {
  const _EmptyWishlist();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Your wishlist is empty',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Save products you want to revisit later.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.storefront),
              label: const Text('Browse products'),
            ),
          ],
        ),
      ),
    );
  }
}
