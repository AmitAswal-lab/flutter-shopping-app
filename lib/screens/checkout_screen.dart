import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cart.dart';
import '../models/cart_item.dart';
import '../providers/order_history.dart';
import '../utils/money.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _placeOrder() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final cart = context.read<Cart>();
    final totalPriceCents = cart.totalPriceCents;
    final customerName = _nameController.text.trim();
    final deliveryAddress = _addressController.text.trim();
    final navigator = Navigator.of(context);

    context.read<OrderHistory>().add(
      customerName: customerName,
      deliveryAddress: deliveryAddress,
      items: cart.items,
    );
    cart.clear();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => OrderSuccessScreen(
          customerName: customerName,
          totalPriceCents: totalPriceCents,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  String? _requiredField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Cart>(
      builder: (context, cart, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Checkout')),
          body: cart.items.isEmpty
              ? const Center(child: Text('Your cart is empty'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _OrderSummary(
                      items: cart.items,
                      totalPriceCents: cart.totalPriceCents,
                    ),
                    const SizedBox(height: 24),
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                            ),
                            textInputAction: TextInputAction.next,
                            validator: _requiredField,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: 'Delivery address',
                            ),
                            maxLines: 3,
                            textInputAction: TextInputAction.done,
                            validator: _requiredField,
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _placeOrder,
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Place order'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _OrderSummary extends StatelessWidget {
  final List<CartItem> items;
  final int totalPriceCents;

  const _OrderSummary({required this.items, required this.totalPriceCents});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Order Summary', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final item in items) _OrderSummaryRow(item: item),
        const Divider(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total'),
            Text(
              formatCents(totalPriceCents),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}

class _OrderSummaryRow extends StatelessWidget {
  final CartItem item;

  const _OrderSummaryRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text('${item.quantity} x ${item.name}')),
          Text(formatCents(item.lineTotalCents)),
        ],
      ),
    );
  }
}
