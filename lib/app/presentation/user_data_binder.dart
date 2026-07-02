import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:shopping_app/features/cart/presentation/controllers/cart.dart';
import 'package:shopping_app/features/orders/presentation/controllers/order_history.dart';
import 'package:shopping_app/features/profile/presentation/controllers/user_profile_controller.dart';
import 'package:shopping_app/features/wishlist/presentation/controllers/wishlist.dart';

class UserDataBinder extends StatefulWidget {
  const UserDataBinder({super.key, required this.child});

  final Widget child;

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

    _auth?.removeListener(_scheduleUserDataBinding);
    _auth = auth..addListener(_scheduleUserDataBinding);
    _scheduleUserDataBinding();
  }

  @override
  void dispose() {
    _auth?.removeListener(_scheduleUserDataBinding);
    super.dispose();
  }

  void _scheduleUserDataBinding() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bindUserData();
    });
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
