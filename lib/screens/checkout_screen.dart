import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart_item.dart';
import '../models/user_profile.dart';
import '../providers/auth_controller.dart';
import '../providers/cart.dart';
import '../providers/order_history.dart';
import '../providers/user_profile.dart';
import '../utils/money.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  bool _isPlacingOrder = false;
  bool _hasPrefilledProfile = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final userProfile = context.watch<UserProfileController>();
    final profile = userProfile.profile;

    if (_hasPrefilledProfile ||
        userProfile.isLoading ||
        !profile.hasDeliveryDetails) {
      return;
    }

    if (_addressController.text.isEmpty &&
        profile.deliveryAddress.trim().isNotEmpty) {
      _addressController.text = profile.deliveryAddress;
    }
    _hasPrefilledProfile = true;
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    final form = _formKey.currentState;
    if (_isPlacingOrder || form == null || !form.validate()) return;

    final cart = context.read<Cart>();
    final auth = context.read<AuthController>();
    final userProfile = context.read<UserProfileController>().profile;
    final totalPriceCents = cart.totalPriceCents;
    final customerName = _customerNameForOrder(auth, userProfile);
    final deliveryAddress = _addressController.text.trim();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isPlacingOrder = true);

    try {
      await context.read<OrderHistory>().add(
        customerName: customerName,
        deliveryAddress: deliveryAddress,
        items: cart.items,
      );
      await cart.clear();
    } catch (_) {
      if (!mounted) return;

      setState(() => _isPlacingOrder = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not place order. Try again.')),
        );
      return;
    }

    if (!mounted) return;

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

  String _customerNameForOrder(AuthController auth, UserProfile userProfile) {
    final fullName = userProfile.fullName.trim();
    if (fullName.isNotEmpty) return fullName;

    final displayName = auth.user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;

    final email = auth.user?.email?.trim();
    if (email != null && email.isNotEmpty) return email;

    return 'Shopper';
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
                            onPressed: _isPlacingOrder ? null : _placeOrder,
                            icon: _isPlacingOrder
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
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
