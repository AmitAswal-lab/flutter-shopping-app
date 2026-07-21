import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../common/centered_message.dart';
import '../../../common/money.dart';
import '../data/order_fulfillment_service.dart';
import '../domain/admin_order.dart';

class OrdersAdminPage extends StatefulWidget {
  const OrdersAdminPage({super.key});

  @override
  State<OrdersAdminPage> createState() => _OrdersAdminPageState();
}

class _OrdersAdminPageState extends State<OrdersAdminPage> {
  final _fulfillment = OrderFulfillmentService();
  String _filter = 'queue';

  Stream<List<AdminOrder>> _orders() {
    final orders = FirebaseFirestore.instance.collectionGroup('orders');
    final Query<Map<String, dynamic>> query;

    switch (_filter) {
      case 'delivered':
        query = orders
            .where('status', isEqualTo: 'delivered')
            .orderBy('createdAt', descending: true);
      case 'all':
        query = orders.orderBy('createdAt', descending: true);
      default:
        query = orders
            .where(
              'status',
              whereIn: const ['paid', 'confirmed', 'processing', 'shipped'],
            )
            .orderBy('createdAt', descending: true);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs.map(AdminOrder.fromDoc).toList(),
    );
  }

  Future<void> _openDetails(AdminOrder order) async {
    final result = await showDialog<_FulfillmentResult>(
      context: context,
      builder: (context) =>
          _OrderDetailDialog(fulfillment: _fulfillment, order: order),
    );
    if (!mounted || result == null) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminOrder>>(
      stream: _orders(),
      builder: (context, snapshot) {
        final orders = snapshot.data ?? const <AdminOrder>[];
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order fulfillment',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Verify payment evidence, then move orders through preparation, shipping, and delivery.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'queue',
                          icon: Icon(Icons.pending_actions_outlined),
                          label: Text('Active queue'),
                        ),
                        ButtonSegment(
                          value: 'delivered',
                          icon: Icon(Icons.inventory_2_outlined),
                          label: Text('Delivered'),
                        ),
                        ButtonSegment(
                          value: 'all',
                          icon: Icon(Icons.list_alt_outlined),
                          label: Text('All orders'),
                        ),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (selection) {
                        setState(() => _filter = selection.first);
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (snapshot.hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: CenteredMessage(
                  icon: Icons.cloud_off_outlined,
                  title: 'Could not load orders',
                  body: snapshot.error.toString(),
                ),
              )
            else if (snapshot.connectionState == ConnectionState.waiting)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: CenteredMessage(
                  icon: Icons.hourglass_empty,
                  title: 'Loading orders',
                ),
              )
            else if (orders.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: CenteredMessage(
                  icon: Icons.inbox_outlined,
                  title: _filter == 'queue'
                      ? 'No active orders'
                      : 'No orders found',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                sliver: SliverList.separated(
                  itemCount: orders.length,
                  itemBuilder: (context, index) => _OrderCard(
                    order: orders[index],
                    onTap: () => _openDetails(orders[index]),
                  ),
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final AdminOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 680;
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.customerName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(context, order.createdAt),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    order.deliveryRecipient.isEmpty
                        ? order.deliveryAddress
                        : '${order.deliveryRecipient} - ${order.deliveryAddress}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${order.itemCount} item${order.itemCount == 1 ? '' : 's'} - ${order.paymentLabel}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              );
              final summary = Column(
                crossAxisAlignment: isCompact
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  _StatusChip(status: order.status),
                  const SizedBox(height: 16),
                  Text(
                    formatMoney(order.totalPriceCents),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('View order'),
                  ),
                ],
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [details, const SizedBox(height: 20), summary],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: details),
                  summary,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OrderDetailDialog extends StatefulWidget {
  const _OrderDetailDialog({required this.fulfillment, required this.order});

  final OrderFulfillmentService fulfillment;
  final AdminOrder order;

  @override
  State<_OrderDetailDialog> createState() => _OrderDetailDialogState();
}

class _OrderDetailDialogState extends State<_OrderDetailDialog> {
  var _isSubmitting = false;
  String? _error;

  Future<void> _confirmAdvance() async {
    final message = widget.order.fulfillmentConfirmation;
    final action = widget.order.nextFulfillmentAction;
    if (message == null || action == null || _isSubmitting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirmationContext) => AlertDialog(
        title: Text('$action?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmationContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(confirmationContext, true),
            child: const Text('Confirm update'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _advance();
  }

  Future<void> _advance() async {
    if (_isSubmitting) return;

    setState(() {
      _error = null;
      _isSubmitting = true;
    });

    try {
      await widget.fulfillment.advance(widget.order);
      if (!mounted) return;
      Navigator.pop(
        context,
        _FulfillmentResult(
          'Order moved to ${_nextStatusLabel(widget.order.status)}.',
        ),
      );
    } on OrderFulfillmentFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final nextAction = order.nextFulfillmentAction;
    return AlertDialog(
      title: Text('Order ${_shortOrderId(order.id)}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatMoney(order.totalPriceCents),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  _StatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: 20),
              _DetailSection(
                title: 'Customer',
                lines: [
                  order.customerName,
                  if (order.deliveryRecipient.isNotEmpty)
                    order.deliveryRecipient,
                  if (order.deliveryPhoneNumber.isNotEmpty)
                    order.deliveryPhoneNumber,
                ],
              ),
              _DetailSection(
                title: 'Delivery address',
                lines: [
                  order.deliveryAddress.isEmpty
                      ? 'No delivery address available'
                      : order.deliveryAddress,
                ],
              ),
              _DetailSection(
                title: 'Payment',
                lines: [
                  order.paymentLabel,
                  if (order.razorpayPaymentId != null)
                    'Payment ${_shortOrderId(order.razorpayPaymentId!)}',
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Items (${order.itemCount})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final item in order.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text('${item.quantity} x ${item.name}')),
                      Text(formatMoney(item.lineTotalCents)),
                    ],
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (nextAction != null)
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _confirmAdvance,
            icon: _isSubmitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.local_shipping_outlined),
            label: Text(nextAction),
          ),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          for (final line in lines) Text(line),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(_statusIcon(status), size: 18),
      label: Text(_statusLabel(status)),
    );
  }
}

class _FulfillmentResult {
  const _FulfillmentResult(this.message);

  final String message;
}

String _statusLabel(String status) => switch (status) {
  'paid' => 'Paid',
  'confirmed' => 'Payment check needed',
  'processing' => 'Preparing',
  'shipped' => 'Shipped',
  'delivered' => 'Delivered',
  'cancelled' => 'Cancelled',
  _ => status.isEmpty ? 'Unknown' : status,
};

String _nextStatusLabel(String status) => switch (status) {
  'paid' => 'Preparing',
  'processing' => 'Shipped',
  'shipped' => 'Delivered',
  _ => 'the next fulfillment stage',
};

IconData _statusIcon(String status) => switch (status) {
  'paid' => Icons.payments_outlined,
  'confirmed' => Icons.warning_amber_outlined,
  'processing' => Icons.inventory_2_outlined,
  'shipped' => Icons.local_shipping_outlined,
  'delivered' => Icons.check_circle_outline,
  _ => Icons.info_outline,
};

String _shortOrderId(String value) {
  if (value.length <= 12) return '#$value';
  return '#${value.substring(0, 8)}';
}

String _formatDateTime(BuildContext context, DateTime value) {
  final localizations = MaterialLocalizations.of(context);
  final date = localizations.formatMediumDate(value);
  final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value));
  return '$date at $time';
}
