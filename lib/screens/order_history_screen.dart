import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart_item.dart';
import '../models/order.dart';
import '../providers/order_history.dart';
import '../utils/date_time_format.dart';
import '../utils/money.dart';

class OrderHistoryScreen extends StatelessWidget {
  final VoidCallback? onBrowseProducts;

  const OrderHistoryScreen({super.key, this.onBrowseProducts});

  @override
  Widget build(BuildContext context) {
    final isEmpty = context.select<OrderHistory, bool>(
      (history) => history.isEmpty,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        actions: [
          if (!isEmpty)
            TextButton(
              onPressed: context.read<OrderHistory>().clear,
              child: const Text('Clear'),
            ),
        ],
      ),
      body: _OrderHistoryBody(onBrowseProducts: onBrowseProducts),
    );
  }
}

class _OrderHistoryBody extends StatelessWidget {
  final VoidCallback? onBrowseProducts;

  const _OrderHistoryBody({this.onBrowseProducts});

  @override
  Widget build(BuildContext context) {
    final orders = context.select<OrderHistory, List<Order>>(
      (history) => history.orders,
    );

    if (orders.isEmpty) {
      return _EmptyOrderHistory(onBrowseProducts: onBrowseProducts);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _OrderHistoryCard(order: orders[index]);
      },
    );
  }
}

class _OrderHistoryCard extends StatelessWidget {
  final Order order;

  const _OrderHistoryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(child: Text(order.totalCount.toString())),
        title: Text(
          formatCents(order.totalPriceCents),
          style: textTheme.titleMedium,
        ),
        subtitle: Text(formatOrderDate(order.createdAt)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Text(order.customerName, style: textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(order.deliveryAddress),
          const SizedBox(height: 12),
          for (final item in order.items) _OrderItemRow(item: item),
        ],
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  final CartItem item;

  const _OrderItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text('${item.quantity} x ${item.name}')),
          Text(formatCents(item.lineTotalCents)),
        ],
      ),
    );
  }
}

class _EmptyOrderHistory extends StatelessWidget {
  final VoidCallback? onBrowseProducts;

  const _EmptyOrderHistory({this.onBrowseProducts});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No orders yet',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Completed checkouts will appear here.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onBrowseProducts ?? () => Navigator.of(context).pop(),
              icon: const Icon(Icons.storefront),
              label: const Text('Browse products'),
            ),
          ],
        ),
      ),
    );
  }
}
