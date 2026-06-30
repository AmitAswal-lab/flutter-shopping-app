import 'package:flutter/material.dart';

import 'package:shopping_app/core/utils/money.dart';
import 'package:shopping_app/features/catalog/domain/models/product.dart';
import 'package:shopping_app/features/catalog/presentation/screens/product_detail_screen.dart';
import 'package:shopping_app/features/catalog/presentation/widgets/product_image.dart';
import 'package:shopping_app/features/wishlist/presentation/widgets/wishlist_icon_button.dart';

class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      child: ProductImage(product: product),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: WishlistIconButton(product: product, filled: true),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 52,
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatCents(product.priceCents),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    _ListPrice(product: product),
                    const SizedBox(height: 12),
                    _DealBadge(discountPercent: product.discountPercent),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListPrice extends StatelessWidget {
  final Product product;

  const _ListPrice({required this.product});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'M.R.P: '),
          TextSpan(
            text: formatCents(product.listPriceCents),
            style: const TextStyle(decoration: TextDecoration.lineThrough),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

class _DealBadge extends StatelessWidget {
  final int discountPercent;

  const _DealBadge({required this.discountPercent});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.error,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            child: Text(
              '$discountPercent% off',
              style: TextStyle(
                color: colorScheme.onError,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Limited time deal',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.error,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              height: 1.05,
            ),
          ),
        ),
      ],
    );
  }
}
