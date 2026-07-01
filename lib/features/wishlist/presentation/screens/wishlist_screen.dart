import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/features/catalog/presentation/controllers/product_catalog.dart';
import 'package:shopping_app/features/catalog/presentation/widgets/product_card.dart';
import 'package:shopping_app/features/wishlist/presentation/controllers/wishlist.dart';

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
    final catalog = context.watch<ProductCatalog>();
    final wishlist = context.watch<Wishlist>();

    if ((catalog.isLoading && catalog.products.isEmpty) ||
        (wishlist.isLoading && wishlist.productIds.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }

    if (wishlist.errorMessage != null && wishlist.productIds.isEmpty) {
      return _WishlistLoadError(
        message: wishlist.errorMessage!,
        onRetry: wishlist.retry,
      );
    }

    if (catalog.errorMessage != null && catalog.products.isEmpty) {
      return _WishlistLoadError(
        message: catalog.errorMessage!,
        onRetry: catalog.load,
      );
    }

    final favoriteProducts = wishlist.favoritesFrom(catalog.products);

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
        childAspectRatio: 0.52,
      ),
      itemBuilder: (context, index) {
        return ProductCard(product: favoriteProducts[index]);
      },
    );
  }
}

class _WishlistLoadError extends StatelessWidget {
  const _WishlistLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load wishlist products',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
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
