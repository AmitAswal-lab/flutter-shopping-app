import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthController extends ChangeNotifier {
  final FirebaseAuth? _auth;
  final String? setupError;
  StreamSubscription<User?>? _authSubscription;

  User? _user;
  bool _isBusy = false;
  String? _errorMessage;

  AuthController.configured()
    : _auth = FirebaseAuth.instance,
      setupError = null {
    final auth = _auth;
    if (auth == null) return;

    _user = auth.currentUser;
    _authSubscription = auth.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  AuthController.unconfigured(this.setupError) : _auth = null;

  User? get user => _user;
  bool get isConfigured => _auth != null;
  bool get isSignedIn => _user != null;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  Future<void> signIn({required String email, required String password}) async {
    await _runAuthAction(() async {
      await _auth?.signInWithEmailAndPassword(email: email, password: password);
    });
  }

  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    await _runAuthAction(() async {
      await _auth?.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    });
  }

  Future<void> signOut() async {
    await _runAuthAction(() async {
      await _auth?.signOut();
    });
  }

  void clearError() {
    if (_errorMessage == null) return;

    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    if (_auth == null) {
      _errorMessage = 'Firebase is not configured yet.';
      notifyListeners();
      return;
    }

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
    } on FirebaseAuthException catch (error) {
      _errorMessage = _messageFor(error);
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  String _messageFor(FirebaseAuthException error) {
    return switch (error.code) {
      'email-already-in-use' => 'An account already exists for this email.',
      'invalid-email' => 'Enter a valid email address.',
      'invalid-credential' => 'Email or password is incorrect.',
      'user-not-found' => 'No account was found for this email.',
      'weak-password' => 'Password should be at least 6 characters.',
      'wrong-password' => 'Email or password is incorrect.',
      _ => error.message ?? 'Authentication failed. Please try again.',
    };
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
