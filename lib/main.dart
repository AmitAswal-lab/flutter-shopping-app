import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'package:shopping_app/app/bootstrap/firebase_setup.dart';
import 'package:shopping_app/app/shopping_app.dart';
import 'package:shopping_app/features/settings/presentation/controllers/app_preferences.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseSetup = await FirebaseSetup.initialize();
  final appPreferences = await AppPreferences.load();

  if (firebaseSetup.isConfigured) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  runApp(
    ShoppingApp(firebaseSetup: firebaseSetup, appPreferences: appPreferences),
  );
}
