import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/features/cart/presentation/controllers/cart.dart';
import 'package:shopping_app/features/cart/presentation/screens/cart_screen.dart';
import 'package:shopping_app/features/catalog/presentation/screens/product_list_screen.dart';
import 'package:shopping_app/features/checkout/presentation/screens/payment_screen.dart';
import 'package:shopping_app/features/orders/domain/models/order.dart';
import 'package:shopping_app/features/orders/presentation/controllers/order_history.dart';
import 'package:shopping_app/features/orders/presentation/screens/order_history_screen.dart';
import 'package:shopping_app/features/profile/presentation/screens/account_screen.dart';
import 'package:shopping_app/features/wishlist/presentation/controllers/wishlist.dart';
import 'package:shopping_app/features/wishlist/presentation/screens/wishlist_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  static const _shopTabIndex = 0;

  int _selectedIndex = 0;

  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
  }

  void _resumePayment(Order order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          orderId: order.id,
          customerName: order.customerName,
          paymentMethod: order.paymentMethod,
          reservationExpiresAt: order.reservationExpiresAt,
          totalPriceCents: order.totalPriceCents,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderCount = context.select<OrderHistory, int>(
      (history) => history.count,
    );
    final wishlistCount = context.select<Wishlist, int>(
      (wishlist) => wishlist.count,
    );
    final cartCount = context.select<Cart, int>((cart) => cart.totalCount);

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const ProductListScreen(),
          WishlistScreen(onBrowseProducts: () => _selectTab(_shopTabIndex)),
          OrderHistoryScreen(
            onBrowseProducts: () => _selectTab(_shopTabIndex),
            onResumePayment: _resumePayment,
          ),
          CartScreen(onBrowseProducts: () => _selectTab(_shopTabIndex)),
          const AccountScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Shop',
          ),
          NavigationDestination(
            icon: _NavigationBadge(
              count: wishlistCount,
              child: const Icon(Icons.favorite_border),
            ),
            selectedIcon: _NavigationBadge(
              count: wishlistCount,
              child: const Icon(Icons.favorite),
            ),
            label: 'Wishlist',
          ),
          NavigationDestination(
            icon: _NavigationBadge(
              count: orderCount,
              child: const Icon(Icons.receipt_long_outlined),
            ),
            selectedIcon: _NavigationBadge(
              count: orderCount,
              child: const Icon(Icons.receipt_long),
            ),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: _NavigationBadge(
              count: cartCount,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            selectedIcon: _NavigationBadge(
              count: cartCount,
              child: const Icon(Icons.shopping_cart),
            ),
            label: 'Cart',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

class _NavigationBadge extends StatelessWidget {
  final int count;
  final Widget child;

  const _NavigationBadge({required this.count, required this.child});

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      child: child,
    );
  }
}
