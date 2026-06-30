import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/core/utils/money.dart';
import 'package:shopping_app/features/cart/domain/models/cart_item.dart';
import 'package:shopping_app/features/cart/presentation/controllers/cart.dart';
import 'package:shopping_app/features/catalog/domain/models/product.dart';
import 'package:shopping_app/features/catalog/presentation/controllers/product_catalog.dart';
import 'package:shopping_app/features/catalog/presentation/widgets/product_image.dart';
import 'package:shopping_app/features/wishlist/presentation/widgets/wishlist_icon_button.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  void _decreaseQuantity() {
    if (_quantity == 1) return;
    setState(() => _quantity--);
  }

  void _increaseQuantity(int maxQuantity) {
    if (_quantity >= maxQuantity) return;
    setState(() => _quantity++);
  }

  Future<void> _addToCart(Product product, int availableToAdd) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (_quantity > availableToAdd) {
        throw CartStockException(
          productName: product.name,
          availableQuantity: product.stockCount,
        );
      }

      await context.read<Cart>().add(
        CartItem(
          productId: product.id,
          name: product.name,
          priceCents: product.priceCents,
          quantity: _quantity,
        ),
        availableStock: product.stockCount,
      );
    } on CartStockException catch (error) {
      if (!mounted) return;

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
      return;
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
    final product =
        context.select<ProductCatalog, Product?>(
          (catalog) => catalog.productById(widget.product.id),
        ) ??
        widget.product;
    final cartQuantity = context.select<Cart, int>(
      (cart) => cart.quantityOf(product.id),
    );
    final remainingStock = product.stockCount - cartQuantity;
    final availableToAdd = remainingStock > 0 ? remainingStock : 0;
    final canAddToCart = availableToAdd >= _quantity;
    final lineTotalCents = product.priceCents * _quantity;

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
            child: ProductImage(product: product, fit: BoxFit.contain),
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
            availableToAdd == 0
                ? product.inStock
                      ? 'All available stock is already in your cart'
                      : 'Currently out of stock'
                : cartQuantity == 0
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
                maxQuantity: availableToAdd,
                onDecrease: _decreaseQuantity,
                onIncrease: () => _increaseQuantity(availableToAdd),
              ),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: canAddToCart
                ? () => _addToCart(product, availableToAdd)
                : null,
            icon: const Icon(Icons.add_shopping_cart),
            label: Text(
              canAddToCart
                  ? 'Add ${formatCents(lineTotalCents)}'
                  : 'Stock limit reached',
            ),
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
  final int maxQuantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _QuantityStepper({
    required this.quantity,
    required this.maxQuantity,
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
          onPressed: quantity >= maxQuantity ? null : onIncrease,
          icon: const Icon(Icons.add),
          tooltip: 'Increase quantity',
        ),
      ],
    );
  }
}
