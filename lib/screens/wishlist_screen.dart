import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/wishlist.dart';
import '../widgets/product_card.dart';

class WishlistScreen extends StatelessWidget {
  final VoidCallback? onBrowseProducts;

  const WishlistScreen({super.key, this.onBrowseProducts});

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
      body: _WishlistBody(onBrowseProducts: onBrowseProducts),
    );
  }
}

class _WishlistBody extends StatelessWidget {
  final VoidCallback? onBrowseProducts;

  const _WishlistBody({this.onBrowseProducts});

  @override
  Widget build(BuildContext context) {
    final favoriteProducts = context.select<Wishlist, List<Product>>(
      (wishlist) => wishlist.favoritesFrom(kProducts),
    );

    if (favoriteProducts.isEmpty) {
      return _EmptyWishlist(onBrowseProducts: onBrowseProducts);
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
  final VoidCallback? onBrowseProducts;

  const _EmptyWishlist({this.onBrowseProducts});

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
              onPressed: onBrowseProducts ?? () => Navigator.of(context).pop(),
              icon: const Icon(Icons.storefront),
              label: const Text('Browse products'),
            ),
          ],
        ),
      ),
    );
  }
}
