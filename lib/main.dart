import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_controller.dart';
import 'providers/cart.dart';
import 'providers/order_history.dart';
import 'providers/product_filter.dart';
import 'providers/wishlist.dart';
import 'screens/main_shell_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseSetup = await FirebaseSetup.initialize();

  runApp(ShoppingApp(firebaseSetup: firebaseSetup));
}

class ShoppingApp extends StatelessWidget {
  final FirebaseSetup firebaseSetup;

  const ShoppingApp({super.key, required this.firebaseSetup});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Cart()),
        ChangeNotifierProvider(create: (_) => ProductFilter()),
        ChangeNotifierProvider(create: (_) => Wishlist()),
        ChangeNotifierProvider(create: (_) => OrderHistory()),
        ChangeNotifierProvider(
          create: (_) => firebaseSetup.isConfigured
              ? AuthController.configured()
              : AuthController.unconfigured(firebaseSetup.errorMessage),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Shopping App',
        theme: AppTheme.dark,
        home: const MainShellScreen(),
      ),
    );
  }
}

class FirebaseSetup {
  final bool isConfigured;
  final String? errorMessage;

  const FirebaseSetup._({
    required this.isConfigured,
    required this.errorMessage,
  });

  static Future<FirebaseSetup> initialize() async {
    try {
      await Firebase.initializeApp();
      return const FirebaseSetup._(isConfigured: true, errorMessage: null);
    } catch (error) {
      return FirebaseSetup._(
        isConfigured: false,
        errorMessage: error.toString(),
      );
    }
  }
}
