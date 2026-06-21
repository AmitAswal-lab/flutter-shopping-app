import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/wishlist.dart';

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

    final icon = Icon(isFavorite ? Icons.favorite : Icons.favorite_border);
    final tooltip = isFavorite ? 'Remove from wishlist' : 'Add to wishlist';

    void toggleFavorite() {
      context.read<Wishlist>().toggle(product.id);
    }

    if (filled) {
      return IconButton.filledTonal(
        onPressed: toggleFavorite,
        icon: icon,
        color: isFavorite ? colorScheme.primary : null,
        tooltip: tooltip,
      );
    }

    return IconButton(
      onPressed: toggleFavorite,
      icon: icon,
      color: isFavorite ? colorScheme.primary : null,
      tooltip: tooltip,
    );
  }
}
