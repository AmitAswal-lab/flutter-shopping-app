import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/cart.dart';
import 'models/order_history.dart';
import 'models/product_filter.dart';
import 'models/wishlist.dart';
import 'screens/main_shell_screen.dart';

void main() {
  runApp(const ShoppingApp());
}

class ShoppingApp extends StatelessWidget {
  const ShoppingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Cart()),
        ChangeNotifierProvider(create: (_) => ProductFilter()),
        ChangeNotifierProvider(create: (_) => Wishlist()),
        ChangeNotifierProvider(create: (_) => OrderHistory()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Shopping App',
        theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        home: const MainShellScreen(),
      ),
    );
  }
}
