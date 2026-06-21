import 'package:flutter/material.dart';

import 'screens/product_list_screen.dart';

void main() {
  runApp(const ShoppingApp());
}

class ShoppingApp extends StatelessWidget {
  const ShoppingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shopping App',
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: const ProductListScreen(),
    );
  }
}
