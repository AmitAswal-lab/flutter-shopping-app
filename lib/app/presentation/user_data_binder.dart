import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:shopping_app/features/cart/presentation/controllers/cart.dart';
import 'package:shopping_app/features/catalog/presentation/controllers/product_catalog.dart';
import 'package:shopping_app/features/notifications/data/services/notification_service.dart';
import 'package:shopping_app/features/orders/presentation/controllers/order_history.dart';
import 'package:shopping_app/features/profile/presentation/controllers/user_profile_controller.dart';
import 'package:shopping_app/features/profile/presentation/controllers/delivery_addresses_controller.dart';
import 'package:shopping_app/features/wishlist/presentation/controllers/wishlist.dart';

class UserDataBinder extends StatefulWidget {
  const UserDataBinder({super.key, required this.child});

  final Widget child;

  @override
  State<UserDataBinder> createState() => _UserDataBinderState();
}

class _UserDataBinderState extends State<UserDataBinder> {
  AuthController? _auth;
  UserProfileController? _profile;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final auth = context.read<AuthController>();
    if (_auth == auth) return;

    _auth?.removeListener(_scheduleUserDataBinding);
    _auth = auth..addListener(_scheduleUserDataBinding);
    final profile = context.read<UserProfileController>();
    if (_profile != profile) {
      _profile?.removeListener(_scheduleLegacyAddressMigration);
      _profile = profile..addListener(_scheduleLegacyAddressMigration);
    }
    _scheduleUserDataBinding();
  }

  @override
  void dispose() {
    _auth?.removeListener(_scheduleUserDataBinding);
    _profile?.removeListener(_scheduleLegacyAddressMigration);
    super.dispose();
  }

  void _scheduleUserDataBinding() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bindUserData();
    });
  }

  void _bindUserData() {
    final user = _auth?.user;
    final userId = user?.emailVerified == true ? user?.uid : null;

    context.read<ProductCatalog>().bindAccess(userId != null);
    context.read<Cart>().bindUser(userId);
    context.read<Wishlist>().bindUser(userId);
    context.read<OrderHistory>().bindUser(userId);
    context.read<UserProfileController>().bindUser(userId);
    context.read<DeliveryAddressesController>().bindUser(userId);
    unawaited(context.read<NotificationService>().bindUser(userId));
  }

  void _scheduleLegacyAddressMigration() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _profile == null) return;
      context.read<DeliveryAddressesController>().migrateLegacyAddress(
        _profile!.profile,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
