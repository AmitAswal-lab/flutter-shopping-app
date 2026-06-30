import 'package:firebase_core/firebase_core.dart';

class FirebaseSetup {
  const FirebaseSetup._({
    required this.isConfigured,
    required this.errorMessage,
  });

  final bool isConfigured;
  final String? errorMessage;

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
