import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/core/utils/date_time_format.dart';
import 'package:shopping_app/core/utils/money.dart';
import 'package:shopping_app/features/orders/domain/models/order.dart';
import 'package:shopping_app/features/orders/presentation/controllers/order_history.dart';
import 'package:shopping_app/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:shopping_app/features/orders/presentation/widgets/order_status_badge.dart';

class OrderHistoryScreen extends StatelessWidget {
  final VoidCallback? onBrowseProducts;
  final ValueChanged<Order>? onResumePayment;

  const OrderHistoryScreen({
    super.key,
    this.onBrowseProducts,
    this.onResumePayment,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order History')),
      body: _OrderHistoryBody(
        onBrowseProducts: onBrowseProducts,
        onResumePayment: onResumePayment,
      ),
    );
  }
}

class _OrderHistoryBody extends StatelessWidget {
  final VoidCallback? onBrowseProducts;
  final ValueChanged<Order>? onResumePayment;

  const _OrderHistoryBody({this.onBrowseProducts, this.onResumePayment});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<OrderHistory>();
    final orders = history.orders;

    if (history.isLoading && orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (history.errorMessage != null && orders.isEmpty) {
      return _OrderHistoryError(
        message: history.errorMessage!,
        onRetry: history.retry,
      );
    }

    if (orders.isEmpty) {
      return _EmptyOrderHistory(onBrowseProducts: onBrowseProducts);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _OrderHistoryCard(
          order: orders[index],
          onResumePayment: onResumePayment,
        );
      },
    );
  }
}

class _OrderHistoryError extends StatelessWidget {
  const _OrderHistoryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load orders',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderHistoryCard extends StatelessWidget {
  final Order order;
  final ValueChanged<Order>? onResumePayment;

  const _OrderHistoryCard({required this.order, this.onResumePayment});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(
                orderId: order.id,
                onResumePayment: onResumePayment,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(child: Text(order.totalCount.toString())),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatCents(order.totalPriceCents),
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatOrderDate(order.createdAt),
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  OrderStatusBadge(status: order.status),
                  const SizedBox(height: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ],
          ),
        ),
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
