import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:shopping_app/features/auth/data/services/account_security_service.dart';

class AuthController extends ChangeNotifier {
  final FirebaseAuth? _auth;
  final String? setupError;
  StreamSubscription<User?>? _authSubscription;

  User? _user;
  bool _isBusy = false;
  String? _errorMessage;
  String? _successMessage;

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
  bool get isEmailVerified => _user?.emailVerified ?? false;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  Future<void> signIn({required String email, required String password}) async {
    await _runAuthAction(() async {
      await _auth?.signInWithEmailAndPassword(email: email, password: password);
    });
  }

  Future<void> createAccount({
    required String email,
    required String password,
    String? displayName,
  }) async {
    await _runAuthAction(() async {
      final credential = await _auth?.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential?.user;
      final name = displayName?.trim();
      if (name != null && name.isNotEmpty) {
        await user?.updateDisplayName(name);
      }

      await user?.sendEmailVerification();
      await user?.reload();
      _user = _auth?.currentUser;
    }, successMessage: 'Verification email sent. Check your inbox.');
  }

  Future<void> updateDisplayName(String displayName) async {
    await _runAuthAction(() async {
      final user = _auth?.currentUser;
      if (user == null) {
        throw FirebaseAuthException(code: 'user-not-found');
      }

      final name = displayName.trim();
      await user.updateDisplayName(name.isEmpty ? null : name);
      await user.reload();
      _user = _auth?.currentUser;
    }, successMessage: 'Profile updated.');
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _runAuthAction(
      () async {
        await _auth?.sendPasswordResetEmail(email: email.trim());
      },
      successMessage:
          'If an account exists for this email, a password reset link has '
          'been sent. Check your inbox and spam folder.',
    );
  }

  Future<void> refreshCurrentUser() async {
    await _runAuthAction(() async {
      final user = _requireCurrentUser();
      await user.reload();
      final refreshedUser = _auth?.currentUser;
      if (refreshedUser?.emailVerified ?? false) {
        await refreshedUser?.getIdToken(true);
      }
      _user = refreshedUser;
    });
  }

  Future<void> sendEmailVerification() async {
    await _runAuthAction(() async {
      final user = _requireCurrentUser();
      if (user.emailVerified) return;

      await user.sendEmailVerification();
    }, successMessage: 'Verification email sent. Check your inbox.');
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _runAuthAction(() async {
      final user = _requireCurrentUser();
      await _reauthenticate(user, currentPassword);
      await user.updatePassword(newPassword);
    }, successMessage: 'Password changed.');
  }

  Future<void> deleteAccount({
    required String currentPassword,
    required AccountSecurityService securityService,
  }) async {
    await _runAuthAction(() async {
      final user = _requireCurrentUser();
      await _reauthenticate(user, currentPassword);
      await securityService.deleteAccount();
      await _auth?.signOut();
      _user = null;
    }, successMessage: 'Account deleted.');
  }

  Future<void> signOut() async {
    await _runAuthAction(() async {
      await _auth?.signOut();
    });
  }

  User _requireCurrentUser() {
    final user = _auth?.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'user-not-found');
    }
    return user;
  }

  Future<void> _reauthenticate(User user, String currentPassword) async {
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(code: 'user-not-found');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
  }

  void clearError() {
    if (_errorMessage == null) return;

    _errorMessage = null;
    notifyListeners();
  }

  void clearMessages() {
    if (_errorMessage == null && _successMessage == null) return;

    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  Future<void> _runAuthAction(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (_auth == null) {
      _errorMessage = 'Firebase is not configured yet.';
      _successMessage = null;
      notifyListeners();
      return;
    }

    _isBusy = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await action();
      _successMessage = successMessage;
    } on AccountSecurityFailure catch (error) {
      _errorMessage = error.message;
      _successMessage = null;
    } on FirebaseAuthException catch (error) {
      _errorMessage = _messageFor(error);
      _successMessage = null;
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
      _successMessage = null;
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
      'requires-recent-login' =>
        'Sign in again before changing account security settings.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'network-request-failed' => 'Check your connection and try again.',
      _ => error.message ?? 'Authentication failed. Please try again.',
    };
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
