import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/core/utils/money.dart';
import 'package:shopping_app/features/cart/domain/models/cart_item.dart';
import 'package:shopping_app/features/cart/presentation/controllers/cart.dart';
import 'package:shopping_app/features/catalog/domain/models/product.dart';
import 'package:shopping_app/features/catalog/presentation/controllers/product_catalog.dart';
import 'package:shopping_app/features/checkout/presentation/screens/checkout_screen.dart';

class CartScreen extends StatelessWidget {
  final VoidCallback? onBrowseProducts;

  const CartScreen({super.key, this.onBrowseProducts});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cart'),
        actions: [
          Consumer<Cart>(
            builder: (context, cart, child) {
              if (cart.items.isEmpty) return const SizedBox.shrink();
              return TextButton(
                onPressed: cart.clear,
                child: const Text('Clear'),
              );
            },
          ),
        ],
      ),
      body: Consumer2<Cart, ProductCatalog>(
        builder: (context, cart, catalog, child) {
          if (cart.items.isEmpty) {
            return _EmptyCart(onBrowseProducts: onBrowseProducts);
          }
          final hasStockIssues = cart.items.any((item) {
            final product = catalog.productById(item.productId);
            return product == null || item.quantity > product.stockCount;
          });

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return _CartRow(
                      item: item,
                      product: catalog.productById(item.productId),
                    );
                  },
                ),
              ),
              _SummaryBar(
                totalCount: cart.totalCount,
                totalPriceCents: cart.totalPriceCents,
                canCheckout: !hasStockIssues,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  final VoidCallback? onBrowseProducts;

  const _EmptyCart({this.onBrowseProducts});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Your cart is empty',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add products to start an order.',
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

class _CartRow extends StatelessWidget {
  final CartItem item;
  final Product? product;

  const _CartRow({required this.item, required this.product});

  Future<void> _setQuantity(BuildContext context, int quantity) async {
    final currentProduct = product;
    if (currentProduct == null) return;

    try {
      await context.read<Cart>().setQuantity(
        item.productId,
        quantity,
        availableStock: currentProduct.stockCount,
      );
    } on CartStockException catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stockCount = product?.stockCount;
    final hasStockIssue = stockCount == null || item.quantity > stockCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('${formatCents(item.priceCents)} each'),
                if (hasStockIssue) ...[
                  const SizedBox(height: 4),
                  Text(
                    stockCount == null
                        ? 'No longer available'
                        : stockCount == 0
                        ? 'Out of stock'
                        : 'Only $stockCount available',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: product == null
                ? () => context.read<Cart>().remove(item.productId)
                : () => _setQuantity(context, item.quantity - 1),
          ),
          Text('${item.quantity}'),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: stockCount == null || item.quantity >= stockCount
                ? null
                : () => _setQuantity(context, item.quantity + 1),
          ),
          SizedBox(
            width: 72,
            child: Text(
              formatCents(item.lineTotalCents),
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final int totalCount;
  final int totalPriceCents;
  final bool canCheckout;

  const _SummaryBar({
    required this.totalCount,
    required this.totalPriceCents,
    required this.canCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total ($totalCount items)',
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                formatCents(totalPriceCents),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (!canCheckout) ...[
            const SizedBox(height: 8),
            Text(
              'Adjust unavailable quantities before checkout.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canCheckout
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CheckoutScreen(),
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.payment),
              label: const Text('Checkout'),
            ),
          ),
        ],
      ),
    );
  }
}
