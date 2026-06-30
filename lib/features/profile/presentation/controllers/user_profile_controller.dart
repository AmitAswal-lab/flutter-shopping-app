import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:shopping_app/features/profile/domain/models/user_profile.dart';

class UserProfileController extends ChangeNotifier {
  final FirebaseFirestore? firestore;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  String? _userId;
  UserProfile _profile = const UserProfile.empty();
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  UserProfileController({this.firestore});

  UserProfile get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  void bindUser(String? userId) {
    if (_userId == userId) return;

    _subscription?.cancel();
    _subscription = null;
    _userId = userId;
    _profile = const UserProfile.empty();
    _errorMessage = null;
    _successMessage = null;

    if (firestore == null || userId == null) {
      _isLoading = false;
      _isSaving = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _subscription = _userDocument.snapshots().listen(
      (snapshot) {
        _profile = snapshot.exists
            ? UserProfile.fromJson(Map<String, Object?>.from(snapshot.data()!))
            : const UserProfile.empty();
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (_) {
        _isLoading = false;
        _errorMessage = 'Could not load profile.';
        notifyListeners();
      },
    );
  }

  Future<void> save(UserProfile profile) async {
    if (!_isFirestoreReady) {
      _profile = profile;
      _successMessage = 'Profile updated.';
      notifyListeners();
      return;
    }

    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _userDocument.set({
        ...profile.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _successMessage = 'Profile updated.';
    } catch (_) {
      _errorMessage = 'Could not save profile. Try again.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    if (_errorMessage == null && _successMessage == null) return;

    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  bool get _isFirestoreReady => firestore != null && _userId != null;

  DocumentReference<Map<String, dynamic>> get _userDocument {
    return firestore!.collection('users').doc(_userId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
