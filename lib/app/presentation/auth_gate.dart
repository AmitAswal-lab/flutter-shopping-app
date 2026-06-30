import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:shopping_app/features/auth/presentation/screens/auth_screen.dart';
import 'package:shopping_app/features/navigation/presentation/screens/main_shell_screen.dart';

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
