import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../utils/money.dart';

class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: const [_CartBadge()],
      ),
      body: ListView.builder(
        itemCount: kProducts.length,
        itemBuilder: (context, index) {
          return _ProductTile(product: kProducts[index]);
        },
      ),
    );
  }
}

class _CartBadge extends StatelessWidget {
  const _CartBadge();

  @override
  Widget build(BuildContext context) {
    final count = context.select<Cart, int>((cart) => cart.totalCount);
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.shopping_cart_outlined),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;

  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(product.emoji, style: const TextStyle(fontSize: 32)),
      title: Text(product.name),
      subtitle: Text(formatCents(product.priceCents)),
      trailing: IconButton(
        icon: const Icon(Icons.add_circle),
        onPressed: () {
          context.read<Cart>().add(
                CartItem(
                  productId: product.id,
                  name: product.name,
                  priceCents: product.priceCents,
                  quantity: 1,
                ),
              );
        },
      ),
    );
  }
}
