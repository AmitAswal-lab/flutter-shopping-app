import 'package:flutter/material.dart';

import '../features/auth/presentation/auth_gate.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shopping Admin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFF9BE7C8),
          primary: const Color(0xFF9BE7C8),
          secondary: const Color(0xFFE5B857),
          surface: const Color(0xFF17141C),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0D13),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
