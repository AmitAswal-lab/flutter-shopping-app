import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cart.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../utils/money.dart';
import '../widgets/wishlist_icon_button.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  int get _lineTotalCents => widget.product.priceCents * _quantity;

  void _decreaseQuantity() {
    if (_quantity == 1) return;
    setState(() => _quantity--);
  }

  void _increaseQuantity() {
    setState(() => _quantity++);
  }

  Future<void> _addToCart() async {
    final product = widget.product;
    final messenger = ScaffoldMessenger.of(context);

    try {
      await context.read<Cart>().add(
        CartItem(
          productId: product.id,
          name: product.name,
          priceCents: product.priceCents,
          quantity: _quantity,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not add item. Try again.')),
        );
      return;
    }

    if (!mounted) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Added $_quantity ${product.name} to cart')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final cartQuantity = context.select<Cart, int>(
      (cart) => cart.quantityOf(product.id),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: [WishlistIconButton(product: product)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Image.asset(product.imageAsset, fit: BoxFit.contain),
          ),
          const SizedBox(height: 24),
          Text(product.brand, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(product.name, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            formatCents(product.priceCents),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _ProductMetaRow(product: product),
          const SizedBox(height: 24),
          Text('Description', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            product.description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Text(
            cartQuantity == 0
                ? 'Not in cart yet'
                : '$cartQuantity already in cart',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Quantity', style: Theme.of(context).textTheme.titleMedium),
              _QuantityStepper(
                quantity: _quantity,
                onDecrease: _decreaseQuantity,
                onIncrease: _increaseQuantity,
              ),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _addToCart,
            icon: const Icon(Icons.add_shopping_cart),
            label: Text('Add ${formatCents(_lineTotalCents)}'),
          ),
        ],
      ),
    );
  }
}

class _ProductMetaRow extends StatelessWidget {
  final Product product;

  const _ProductMetaRow({required this.product});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ProductMetaChip(
          icon: Icons.category_outlined,
          label: product.category.label,
        ),
        _ProductMetaChip(
          icon: Icons.star_rounded,
          label:
              '${product.rating.toStringAsFixed(1)} (${product.reviewCount})',
        ),
        _ProductMetaChip(
          icon: Icons.inventory_2_outlined,
          label: '${product.stockCount} in stock',
        ),
      ],
    );
  }
}

class _ProductMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ProductMetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _QuantityStepper({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          onPressed: quantity == 1 ? null : onDecrease,
          icon: const Icon(Icons.remove),
          tooltip: 'Decrease quantity',
        ),
        SizedBox(
          width: 48,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton.outlined(
          onPressed: onIncrease,
          icon: const Icon(Icons.add),
          tooltip: 'Increase quantity',
        ),
      ],
    );
  }
}
