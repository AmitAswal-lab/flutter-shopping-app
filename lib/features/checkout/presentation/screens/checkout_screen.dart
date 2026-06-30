import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/core/utils/money.dart';
import 'package:shopping_app/features/cart/domain/models/cart_item.dart';
import 'package:shopping_app/features/cart/presentation/controllers/cart.dart';
import 'package:shopping_app/features/catalog/presentation/controllers/product_catalog.dart';
import 'package:shopping_app/features/checkout/data/services/checkout_service.dart';
import 'package:shopping_app/features/checkout/domain/models/payment.dart';
import 'package:shopping_app/features/checkout/presentation/screens/order_success_screen.dart';
import 'package:shopping_app/features/checkout/presentation/screens/payment_screen.dart';
import 'package:shopping_app/features/profile/presentation/controllers/user_profile_controller.dart';

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
        paymentMethod: PaymentMethod.razorpay,
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
                          const ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.verified_user_outlined),
                            title: Text('Razorpay Test Mode'),
                            subtitle: Text('Card, UPI and other test methods'),
                            trailing: Text('TEST'),
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
