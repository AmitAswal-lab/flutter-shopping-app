import 'package:flutter/material.dart';

import '../models/product.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.product,
    this.fit = BoxFit.cover,
  });

  final Product product;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl;
    if (imageUrl == null) {
      return _AssetProductImage(product: product, fit: fit);
    }

    return Image.network(
      imageUrl,
      fit: fit,
      width: double.infinity,
      semanticLabel: product.name,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;

        return Stack(
          fit: StackFit.expand,
          children: [
            _AssetProductImage(product: product, fit: fit),
            ColoredBox(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.72),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ],
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return _AssetProductImage(product: product, fit: fit);
      },
    );
  }
}

class _AssetProductImage extends StatelessWidget {
  const _AssetProductImage({required this.product, required this.fit});

  final Product product;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      product.imageAsset,
      fit: fit,
      width: double.infinity,
      semanticLabel: product.name,
      errorBuilder: (context, error, stackTrace) {
        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }
}
