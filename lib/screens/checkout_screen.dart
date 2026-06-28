import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart_item.dart';
import '../models/payment.dart';
import '../providers/cart.dart';
import '../providers/product_catalog.dart';
import '../providers/user_profile.dart';
import '../services/checkout_service.dart';
import '../utils/money.dart';
import 'order_success_screen.dart';
import 'payment_screen.dart';

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
  String? _checkoutId;
  PaymentMethod _paymentMethod = PaymentMethod.testCard;

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
    final catalog = context.read<ProductCatalog>();
    final checkout = context.read<CheckoutService>();
    final deliveryAddress = _addressController.text.trim();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isPlacingOrder = true);

    try {
      await catalog.refreshFromServer();
    } catch (_) {
      if (!mounted) return;

      setState(() => _isPlacingOrder = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not verify current stock. Try again.'),
          ),
        );
      return;
    }

    final stockIssue = _stockIssue(cart, catalog);
    if (stockIssue != null) {
      if (!mounted) return;

      setState(() => _isPlacingOrder = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(stockIssue)));
      return;
    }

    try {
      _checkoutId ??= checkout.createCheckoutId();
      final result = await checkout.placeOrder(
        checkoutId: _checkoutId!,
        deliveryAddress: deliveryAddress,
        items: cart.items,
        paymentMethod: _paymentMethod,
      );

      if (!mounted) return;

      if (result.status.isSuccessful) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => OrderSuccessScreen(
              customerName: result.customerName,
              totalPriceCents: result.totalPriceCents,
            ),
          ),
          (route) => route.isFirst,
        );
        return;
      }

      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            orderId: result.orderId,
            customerName: result.customerName,
            paymentMethod: result.paymentMethod,
            reservationExpiresAt: result.reservationExpiresAt,
            totalPriceCents: result.totalPriceCents,
          ),
        ),
      );
      return;
    } on CheckoutFailure catch (error) {
      if (!mounted) return;

      setState(() => _isPlacingOrder = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
      return;
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
  }

  String? _stockIssue(Cart cart, ProductCatalog catalog) {
    for (final item in cart.items) {
      final product = catalog.productById(item.productId);
      if (product == null) {
        return '${item.name} is no longer available.';
      }
      if (product.stockCount <= 0) {
        return '${item.name} is out of stock.';
      }
      if (item.quantity > product.stockCount) {
        return 'Only ${product.stockCount} ${item.name} available.';
      }
    }

    return null;
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
                          Text(
                            'Payment method',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<PaymentMethod>(
                              segments: const [
                                ButtonSegment(
                                  value: PaymentMethod.testCard,
                                  icon: Icon(Icons.credit_card),
                                  label: Text('Test card'),
                                ),
                                ButtonSegment(
                                  value: PaymentMethod.testUpi,
                                  icon: Icon(Icons.qr_code),
                                  label: Text('Test UPI'),
                                ),
                              ],
                              selected: {_paymentMethod},
                              onSelectionChanged: _isPlacingOrder
                                  ? null
                                  : (selection) {
                                      setState(
                                        () => _paymentMethod = selection.first,
                                      );
                                    },
                            ),
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
                                : const Icon(Icons.arrow_forward),
                            label: const Text('Continue to payment'),
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
