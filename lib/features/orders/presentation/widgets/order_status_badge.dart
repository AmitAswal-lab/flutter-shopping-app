import 'package:flutter/material.dart';

import 'package:shopping_app/features/orders/domain/models/order_status.dart';

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      OrderStatus.delivered => (colorScheme.primary, colorScheme.onPrimary),
      OrderStatus.paid ||
      OrderStatus.confirmed ||
      OrderStatus.processing ||
      OrderStatus.shipped => (
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
      ),
      OrderStatus.pendingPayment => (
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
      ),
      _ => (colorScheme.errorContainer, colorScheme.onErrorContainer),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}
