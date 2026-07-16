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
import 'package:shopping_app/features/checkout/presentation/widgets/delivery_address_card.dart';
import 'package:shopping_app/features/profile/domain/models/delivery_address.dart';
import 'package:shopping_app/features/profile/presentation/controllers/delivery_addresses_controller.dart';
import 'package:shopping_app/features/profile/presentation/screens/delivery_profile_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isPlacingOrder = false;
  String? _checkoutId;
  String? _selectedAddressId;

  Future<void> _placeOrder(DeliveryAddress? deliveryAddress) async {
    if (_isPlacingOrder || deliveryAddress == null) return;

    final cart = context.read<Cart>();
    final catalog = context.read<ProductCatalog>();
    final checkout = context.read<CheckoutService>();
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
        deliveryAddressId: deliveryAddress.id,
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
    } on CheckoutFailure catch (error) {
      if (!mounted) return;
      setState(() => _isPlacingOrder = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPlacingOrder = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not place order. Try again.')),
        );
    }
  }

  Future<void> _selectDeliveryAddress(
    BuildContext context,
    List<DeliveryAddress> addresses,
    String? selectedAddressId,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Choose delivery address')),
            for (final address in addresses)
              ListTile(
                leading: Icon(
                  address.id == selectedAddressId
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(address.label),
                subtitle: Text(address.summary, maxLines: 2),
                onTap: () => Navigator.of(sheetContext).pop(address.id),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('Manage addresses'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DeliveryProfileScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _selectedAddressId = selected);
    }
  }

  String? _stockIssue(Cart cart, ProductCatalog catalog) {
    for (final item in cart.items) {
      final product = catalog.productById(item.productId);
      if (product == null) return '${item.name} is no longer available.';
      if (product.stockCount <= 0) return '${item.name} is out of stock.';
      if (item.quantity > product.stockCount) {
        return 'Only ${product.stockCount} ${item.name} available.';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final deliveryAddresses = context.watch<DeliveryAddressesController>();
    final selectedAddress = _selectedAddressId == null
        ? deliveryAddresses.defaultAddress
        : _findAddress(deliveryAddresses.addresses, _selectedAddressId!);

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
                    DeliveryAddressCard(
                      address: selectedAddress,
                      onChange: deliveryAddresses.isLoading
                          ? null
                          : () => _selectDeliveryAddress(
                              context,
                              deliveryAddresses.addresses,
                              selectedAddress?.id,
                            ),
                      onAdd: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DeliveryProfileScreen(),
                        ),
                      ),
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
                      onPressed: _isPlacingOrder || selectedAddress == null
                          ? null
                          : () => _placeOrder(selectedAddress),
                      icon: _isPlacingOrder
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward),
                      label: const Text('Continue to payment'),
                    ),
                  ],
                ),
        );
      },
    );
  }

  DeliveryAddress? _findAddress(List<DeliveryAddress> addresses, String id) {
    for (final address in addresses) {
      if (address.id == id) return address;
    }
    return null;
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.items, required this.totalPriceCents});

  final List<CartItem> items;
  final int totalPriceCents;

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
  const _OrderSummaryRow({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text('${item.quantity} x ${item.name}')),
          Text(formatCents(item.priceCents * item.quantity)),
        ],
      ),
    );
  }
}
