import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart.dart';
import '../models/order_history.dart';
import '../models/wishlist.dart';
import 'cart_screen.dart';
import 'order_history_screen.dart';
import 'product_list_screen.dart';
import 'wishlist_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;

  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
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
          WishlistScreen(onBrowseProducts: () => _selectTab(0)),
          OrderHistoryScreen(onBrowseProducts: () => _selectTab(0)),
          CartScreen(onBrowseProducts: () => _selectTab(0)),
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
