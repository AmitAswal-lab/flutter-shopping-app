import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../catalog/presentation/catalog_admin_page.dart';
import '../../orders/presentation/orders_admin_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.user});

  final User user;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  var _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child: NavigationRail(
              selectedIndex: _selectedIndex,
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Icon(Icons.storefront_outlined, size: 30),
              ),
              trailing: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: IconButton(
                  tooltip: 'Sign out',
                  onPressed: FirebaseAuth.instance.signOut,
                  icon: const Icon(Icons.logout),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: Text('Catalog'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.local_shipping_outlined),
                  selectedIcon: Icon(Icons.local_shipping),
                  label: Text('Orders'),
                ),
              ],
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                CatalogAdminPage(user: widget.user),
                const OrdersAdminPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
