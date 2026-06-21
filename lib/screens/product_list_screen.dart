import 'package:flutter/material.dart';

import '../models/product.dart';
import '../utils/money.dart';

class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shop')),
      body: ListView.builder(
        itemCount: kProducts.length,
        itemBuilder: (context, index) {
          return _ProductTile(product: kProducts[index]);
        },
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
      trailing: Text(
        formatCents(product.priceCents),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
