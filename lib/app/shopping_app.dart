import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/app/bootstrap/firebase_setup.dart';
import 'package:shopping_app/app/presentation/auth_gate.dart';
import 'package:shopping_app/app/presentation/user_data_binder.dart';
import 'package:shopping_app/core/theme/app_theme.dart';
import 'package:shopping_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:shopping_app/features/cart/presentation/controllers/cart.dart';
import 'package:shopping_app/features/catalog/presentation/controllers/product_catalog.dart';
import 'package:shopping_app/features/catalog/presentation/controllers/product_filter.dart';
import 'package:shopping_app/features/checkout/data/services/checkout_service.dart';
import 'package:shopping_app/features/checkout/data/services/payment_service.dart';
import 'package:shopping_app/features/orders/data/services/order_lifecycle_service.dart';
import 'package:shopping_app/features/orders/presentation/controllers/order_history.dart';
import 'package:shopping_app/features/profile/presentation/controllers/user_profile_controller.dart';
import 'package:shopping_app/features/reviews/data/services/review_service.dart';
import 'package:shopping_app/features/reviews/presentation/controllers/product_reviews.dart';
import 'package:shopping_app/features/settings/presentation/controllers/app_preferences.dart';
import 'package:shopping_app/features/wishlist/presentation/controllers/wishlist.dart';

class ShoppingApp extends StatelessWidget {
  const ShoppingApp({
    super.key,
    required this.firebaseSetup,
    required this.appPreferences,
  });

  final FirebaseSetup firebaseSetup;
  final AppPreferences appPreferences;

  @override
  Widget build(BuildContext context) {
    final firestore = firebaseSetup.isConfigured
        ? FirebaseFirestore.instance
        : null;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appPreferences),
        ChangeNotifierProvider(create: (_) => Cart(firestore: firestore)),
        ChangeNotifierProvider(
          create: (_) => ProductCatalog(firestore: firestore),
        ),
        Provider(
          create: (_) => firestore == null
              ? const CheckoutService.unconfigured()
              : CheckoutService.configured(firestore: firestore),
        ),
        Provider(
          create: (_) => firebaseSetup.isConfigured
              ? PaymentService.configured()
              : const PaymentService.unconfigured(),
        ),
        Provider(
          create: (_) => firebaseSetup.isConfigured
              ? OrderLifecycleService.configured()
              : const OrderLifecycleService.unconfigured(),
        ),
        Provider(
          create: (_) => firebaseSetup.isConfigured
              ? ReviewService.configured()
              : const ReviewService.unconfigured(),
        ),
        ChangeNotifierProvider(create: (_) => ProductFilter()),
        ChangeNotifierProvider(
          create: (_) => ProductReviews(firestore: firestore),
        ),
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
      child: Consumer<AppPreferences>(
        builder: (context, preferences, child) {
          return UserDataBinder(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Shopping App',
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: preferences.themeMode,
              home: const AuthGate(),
            ),
          );
        },
      ),
    );
  }
}
