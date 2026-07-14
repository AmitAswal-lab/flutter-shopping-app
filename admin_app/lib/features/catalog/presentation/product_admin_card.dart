import 'package:flutter/material.dart';

import '../../../common/money.dart';
import '../domain/admin_product.dart';

class ProductAdminCard extends StatelessWidget {
  const ProductAdminCard({
    super.key,
    required this.product,
    required this.onEdit,
  });

  final AdminProduct product;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final muted = !product.isActive;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 190,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: product.imageUrl == null
                        ? const Icon(Icons.image_outlined, size: 56)
                        : Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            semanticLabel: '${product.name} product image',
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.broken_image_outlined,
                                  size: 56,
                                ),
                          ),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Chip(
                      label: Text(muted ? 'Archived' : 'Active'),
                      avatar: Icon(
                        muted ? Icons.archive_outlined : Icons.check_circle,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.brand,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.category_outlined,
                        text: product.categoryLabel,
                      ),
                      _InfoChip(
                        icon: Icons.inventory_2_outlined,
                        text: '${product.stockCount} stock',
                      ),
                      _InfoChip(
                        icon: Icons.sort,
                        text: 'Sort ${product.sortOrder}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        formatMoney(product.priceCents),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'MRP ${formatMoney(product.listPriceCents)}',
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${product.rating.toStringAsFixed(1)} stars • ${product.reviewCount} reviews',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(text));
  }
}
