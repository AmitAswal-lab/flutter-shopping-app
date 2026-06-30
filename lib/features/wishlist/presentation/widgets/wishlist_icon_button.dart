import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/features/catalog/domain/models/product.dart';
import 'package:shopping_app/features/wishlist/presentation/controllers/wishlist.dart';

class WishlistIconButton extends StatelessWidget {
  final Product product;
  final bool filled;

  const WishlistIconButton({
    super.key,
    required this.product,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final isFavorite = context.select<Wishlist, bool>(
      (wishlist) => wishlist.isFavorite(product.id),
    );
    final colorScheme = Theme.of(context).colorScheme;
    const favoriteColor = Color(0xFFFF7A90);
    const favoriteContainerColor = Color(0xFF4D1722);

    final icon = Icon(isFavorite ? Icons.favorite : Icons.favorite_border);
    final tooltip = isFavorite ? 'Remove from wishlist' : 'Add to wishlist';
    void onPressed() {
      context.read<Wishlist>().toggle(product.id);
    }

    if (filled) {
      return IconButton.filledTonal(
        onPressed: onPressed,
        icon: icon,
        color: isFavorite ? favoriteColor : null,
        style: IconButton.styleFrom(
          backgroundColor: isFavorite
              ? favoriteContainerColor
              : colorScheme.surfaceContainerHighest,
        ),
        tooltip: tooltip,
      );
    }

    return IconButton(
      onPressed: onPressed,
      icon: icon,
      color: isFavorite ? favoriteColor : null,
      tooltip: tooltip,
    );
  }
}
