import 'package:flutter/material.dart';

import 'package:shopping_app/app/bootstrap/firebase_setup.dart';
import 'package:shopping_app/app/shopping_app.dart';
import 'package:shopping_app/features/settings/presentation/controllers/app_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseSetup = await FirebaseSetup.initialize();
  final appPreferences = await AppPreferences.load();

  runApp(
    ShoppingApp(firebaseSetup: firebaseSetup, appPreferences: appPreferences),
  );
}
