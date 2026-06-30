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

    if (catalog.isLoading && catalog.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (catalog.errorMessage != null && catalog.products.isEmpty) {
      return _WishlistCatalogError(message: catalog.errorMessage!);
    }

    final favoriteProducts = context.watch<Wishlist>().favoritesFrom(
      catalog.products,
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
        childAspectRatio: 0.52,
      ),
      itemBuilder: (context, index) {
        return ProductCard(product: favoriteProducts[index]);
      },
    );
  }
}

class _WishlistCatalogError extends StatelessWidget {
  const _WishlistCatalogError({required this.message});

  final String message;

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
              onPressed: context.read<ProductCatalog>().load,
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
