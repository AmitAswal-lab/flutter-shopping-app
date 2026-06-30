import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/core/utils/date_time_format.dart';
import 'package:shopping_app/core/utils/money.dart';
import 'package:shopping_app/features/cart/domain/models/cart_item.dart';
import 'package:shopping_app/features/orders/data/services/order_lifecycle_service.dart';
import 'package:shopping_app/features/orders/domain/models/order.dart';
import 'package:shopping_app/features/orders/domain/models/order_status.dart';
import 'package:shopping_app/features/orders/presentation/controllers/order_history.dart';
import 'package:shopping_app/features/orders/presentation/widgets/order_status_badge.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.onResumePayment,
  });

  final String orderId;
  final ValueChanged<Order>? onResumePayment;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _isStartingDemo = false;

  Future<void> _startDemo(Order order) async {
    setState(() => _isStartingDemo = true);

    try {
      await context.read<OrderLifecycleService>().startDemo(order.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Delivery simulation started. Status will update automatically.',
          ),
        ),
      );
    } on OrderLifecycleFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isStartingDemo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = context.select<OrderHistory, Order?>(
      (history) => history.orderById(widget.orderId),
    );

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order details')),
        body: const Center(child: Text('Order is no longer available.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Order details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _OrderSummary(order: order),
          const SizedBox(height: 24),
          if (order.status.hasFulfillmentProgress) ...[
            _SectionTitle(title: 'Delivery progress'),
            const SizedBox(height: 12),
            _OrderTimeline(order: order),
            if (order.status.canAdvanceFulfillmentDemo) ...[
              const SizedBox(height: 20),
              if (order.isLifecycleDemoEnabled)
                const _DemoRunningIndicator()
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isStartingDemo ? null : () => _startDemo(order),
                    icon: _isStartingDemo
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(
                      _isStartingDemo
                          ? 'Starting simulation'
                          : 'Simulate delivery progress',
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 28),
          ] else ...[
            _OrderStateMessage(status: order.status),
            const SizedBox(height: 24),
          ],
          _SectionTitle(title: 'Items (${order.totalCount})'),
          const SizedBox(height: 8),
          for (final item in order.items) _OrderItemRow(item: item),
          const Divider(height: 32),
          _TotalRow(totalPriceCents: order.totalPriceCents),
          const SizedBox(height: 28),
          const _SectionTitle(title: 'Delivery address'),
          const SizedBox(height: 8),
          Text(
            order.deliveryAddress.isEmpty
                ? 'No delivery address available'
                : order.deliveryAddress,
          ),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'Payment'),
          const SizedBox(height: 8),
          Text(order.paymentMethod.label),
          const SizedBox(height: 4),
          Text(
            'Order ${_shortOrderId(order.id)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (order.canResumePayment && widget.onResumePayment != null) ...[
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => widget.onResumePayment!(order),
              icon: const Icon(Icons.payment),
              label: const Text('Complete payment'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DemoRunningIndicator extends StatelessWidget {
  const _DemoRunningIndicator();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 8),
        Text(
          'Demo progression is running. Each stage may take about a minute.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatCents(order.totalPriceCents),
                    style: textTheme.headlineSmall,
                  ),
                ),
                OrderStatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Placed ${formatOrderDate(order.createdAt)}',
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderTimeline extends StatelessWidget {
  const _OrderTimeline({required this.order});

  final Order order;

  static const _steps = [
    (OrderStatus.paid, 'Payment confirmed', Icons.payments_outlined),
    (
      OrderStatus.processing,
      'Preparing your order',
      Icons.inventory_2_outlined,
    ),
    (OrderStatus.shipped, 'Shipped', Icons.local_shipping_outlined),
    (OrderStatus.delivered, 'Delivered', Icons.home_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < _steps.length; index++)
          _TimelineStep(
            icon: _steps[index].$3,
            isComplete: index <= order.status.fulfillmentStep,
            isLast: index == _steps.length - 1,
            label: _steps[index].$2,
            timestamp: order.timestampFor(_steps[index].$1),
          ),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.icon,
    required this.isComplete,
    required this.isLast,
    required this.label,
    required this.timestamp,
  });

  final IconData icon;
  final bool isComplete;
  final bool isLast;
  final String label;
  final DateTime? timestamp;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = colorScheme.primary;
    final inactiveColor = colorScheme.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isComplete
                        ? activeColor
                        : colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isComplete ? Icons.check : icon,
                    size: 20,
                    color: isComplete
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isComplete ? activeColor : inactiveColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: isComplete ? null : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (timestamp != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      formatOrderDate(timestamp!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ] else if (!isComplete) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Pending',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderStateMessage extends StatelessWidget {
  const _OrderStateMessage({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final message = switch (status) {
      OrderStatus.pendingPayment =>
        'Payment is still required before this order can be prepared.',
      OrderStatus.paymentFailed =>
        'Payment was not completed. No inventory remains reserved.',
      OrderStatus.cancelled => 'This order was cancelled.',
      OrderStatus.expired => 'The payment reservation for this order expired.',
      _ => 'This order is not currently being fulfilled.',
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: status == OrderStatus.pendingPayment
            ? colorScheme.secondaryContainer
            : colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('${item.quantity}x'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name),
                const SizedBox(height: 2),
                Text(
                  '${formatCents(item.priceCents)} each',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(formatCents(item.lineTotalCents)),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.totalPriceCents});

  final int totalPriceCents;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text('Total', style: Theme.of(context).textTheme.titleMedium),
        ),
        Text(
          formatCents(totalPriceCents),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

String _shortOrderId(String orderId) {
  if (orderId.length <= 10) return '#$orderId';
  return '#${orderId.substring(0, 10)}';
}
