import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'providers/auth_controller.dart';
import 'providers/cart.dart';
import 'providers/order_history.dart';
import 'providers/product_filter.dart';
import 'providers/user_profile.dart';
import 'providers/wishlist.dart';
import 'screens/auth_screen.dart';
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
    final firestore = firebaseSetup.isConfigured
        ? FirebaseFirestore.instance
        : null;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Cart(firestore: firestore)),
        ChangeNotifierProvider(create: (_) => ProductFilter()),
        ChangeNotifierProvider(create: (_) => Wishlist(firestore: firestore)),
        ChangeNotifierProvider(
          create: (_) => OrderHistory(firestore: firestore),
        ),
        ChangeNotifierProvider(
          create: (_) => UserProfileController(firestore: firestore),
        ),
        ChangeNotifierProvider(
          create: (_) => firebaseSetup.isConfigured
              ? AuthController.configured()
              : AuthController.unconfigured(firebaseSetup.errorMessage),
        ),
      ],
      child: UserDataBinder(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Shopping App',
          theme: AppTheme.dark,
          home: const AuthGate(),
        ),
      ),
    );
  }
}

class UserDataBinder extends StatefulWidget {
  final Widget child;

  const UserDataBinder({super.key, required this.child});

  @override
  State<UserDataBinder> createState() => _UserDataBinderState();
}

class _UserDataBinderState extends State<UserDataBinder> {
  AuthController? _auth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final auth = context.read<AuthController>();
    if (_auth == auth) return;

    _auth?.removeListener(_bindUserData);
    _auth = auth..addListener(_bindUserData);
    _bindUserData();
  }

  @override
  void dispose() {
    _auth?.removeListener(_bindUserData);
    super.dispose();
  }

  void _bindUserData() {
    final userId = _auth?.user?.uid;

    context.read<Cart>().bindUser(userId);
    context.read<Wishlist>().bindUser(userId);
    context.read<OrderHistory>().bindUser(userId);
    context.read<UserProfileController>().bindUser(userId);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    if (!auth.isConfigured || !auth.isSignedIn) {
      return const AuthScreen();
    }

    return const MainShellScreen();
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
