import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cart.dart';
import '../models/cart_item.dart';
import '../utils/money.dart';
import 'checkout_screen.dart';

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
      body: Consumer<Cart>(
        builder: (context, cart, child) {
          if (cart.items.isEmpty) {
            return _EmptyCart(onBrowseProducts: onBrowseProducts);
          }
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    return _CartRow(item: cart.items[index]);
                  },
                ),
              ),
              _SummaryBar(
                totalCount: cart.totalCount,
                totalPriceCents: cart.totalPriceCents,
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

  const _CartRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<Cart>();
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
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () =>
                cart.setQuantity(item.productId, item.quantity - 1),
          ),
          Text('${item.quantity}'),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () =>
                cart.setQuantity(item.productId, item.quantity + 1),
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

  const _SummaryBar({required this.totalCount, required this.totalPriceCents});

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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                );
              },
              icon: const Icon(Icons.payment),
              label: const Text('Checkout'),
            ),
          ),
        ],
      ),
    );
  }
}
