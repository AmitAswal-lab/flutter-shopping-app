import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:shopping_app/features/profile/domain/models/delivery_address.dart';
import 'package:shopping_app/features/profile/domain/models/user_profile.dart';

class DeliveryAddressesController extends ChangeNotifier {
  DeliveryAddressesController({this.firestore});

  final FirebaseFirestore? firestore;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  String? _userId;
  List<DeliveryAddress> _addresses = const [];
  UserProfile? _legacyProfile;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _legacyMigrationInFlight = false;
  String? _errorMessage;

  List<DeliveryAddress> get addresses => List.unmodifiable(_addresses);
  DeliveryAddress? get defaultAddress {
    for (final address in _addresses) {
      if (address.isDefault) return address;
    }
    return _addresses.isEmpty ? null : _addresses.first;
  }

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  void bindUser(String? userId) {
    if (_userId == userId) return;

    _subscription?.cancel();
    _subscription = null;
    _userId = userId;
    _addresses = const [];
    _legacyProfile = null;
    _errorMessage = null;
    _legacyMigrationInFlight = false;

    if (firestore == null || userId == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();
    _subscription = _addressesCollection.snapshots().listen(
      (snapshot) {
        _addresses =
            snapshot.docs
                .map(
                  (document) => DeliveryAddress.fromJson(
                    document.id,
                    Map<String, Object?>.from(document.data()),
                  ),
                )
                .toList()
              ..sort((left, right) {
                if (left.isDefault != right.isDefault) {
                  return left.isDefault ? -1 : 1;
                }
                return left.label.toLowerCase().compareTo(
                  right.label.toLowerCase(),
                );
              });
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        unawaited(_tryMigrateLegacyAddress());
      },
      onError: (_) {
        _isLoading = false;
        _errorMessage = 'Could not load delivery addresses.';
        notifyListeners();
      },
    );
  }

  void migrateLegacyAddress(UserProfile profile) {
    _legacyProfile = profile;
    unawaited(_tryMigrateLegacyAddress());
  }

  Future<void> save(DeliveryAddress address) async {
    if (!_isReady) {
      _errorMessage = 'Delivery addresses are unavailable.';
      notifyListeners();
      return;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final reference = address.id.isEmpty
          ? _addressesCollection.doc()
          : _addressesCollection.doc(address.id);
      final existingAddress = _addressById(address.id);
      final makeDefault =
          address.isDefault || _addresses.isEmpty || existingAddress?.isDefault == true;
      final data = <String, Object?>{
        'label': address.label.trim(),
        'fullName': address.fullName.trim(),
        'phoneNumber': address.phoneNumber.trim(),
        'address': address.address.trim(),
        'isDefault': makeDefault,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (address.id.isEmpty) data['createdAt'] = FieldValue.serverTimestamp();

      if (makeDefault) {
        final existing = await _addressesCollection.get();
        final batch = firestore!.batch();
        for (final document in existing.docs) {
          if (document.id != reference.id &&
              document.data()['isDefault'] == true) {
            batch.update(document.reference, {
              'isDefault': false,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
        batch.set(reference, data, SetOptions(merge: true));
        await batch.commit();
      } else {
        await reference.set(data, SetOptions(merge: true));
      }
    } catch (_) {
      _errorMessage = 'Could not save this address. Try again.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> setDefault(String addressId) async {
    final address = _addressById(addressId);
    if (address == null || address.isDefault || !_isReady) return;
    await save(address.copyWith(isDefault: true));
  }

  Future<void> delete(String addressId) async {
    if (!_isReady) return;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final address = _addressById(addressId);
      await _addressesCollection.doc(addressId).delete();
      if (address?.isDefault == true) {
        DeliveryAddress? replacement;
        for (final item in _addresses) {
          if (item.id != addressId) {
            replacement = item;
            break;
          }
        }
        if (replacement != null) await setDefault(replacement.id);
      }
    } catch (_) {
      _errorMessage = 'Could not delete this address. Try again.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _tryMigrateLegacyAddress() async {
    final profile = _legacyProfile;
    if (_legacyMigrationInFlight ||
        _isLoading ||
        !_isReady ||
        _addresses.isNotEmpty ||
        profile == null ||
        profile.deliveryAddressMigrated ||
        profile.deliveryAddress.trim().isEmpty) {
      return;
    }

    _legacyMigrationInFlight = true;
    try {
      await firestore!.runTransaction((transaction) async {
        final profileSnapshot = await transaction.get(_userDocument);
        final addressSnapshot = await transaction.get(
          _addressesCollection.doc('legacy-default'),
        );
        if (addressSnapshot.exists) return;

        final data = profileSnapshot.data() ?? const <String, dynamic>{};
        if (data['deliveryAddressMigrated'] == true ||
            (data['deliveryAddress'] as String? ?? '').trim().isEmpty) {
          return;
        }

        transaction.set(_addressesCollection.doc('legacy-default'), {
          'label': 'Default address',
          'fullName': (data['fullName'] as String? ?? '').trim(),
          'phoneNumber': (data['phoneNumber'] as String? ?? '').trim(),
          'address': (data['deliveryAddress'] as String).trim(),
          'isDefault': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(_userDocument, {
          'deliveryAddressMigrated': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (_) {
      // A migration failure should not prevent normal address management.
    } finally {
      _legacyMigrationInFlight = false;
    }
  }

  bool get _isReady => firestore != null && _userId != null;

  DeliveryAddress? _addressById(String id) {
    for (final address in _addresses) {
      if (address.id == id) return address;
    }
    return null;
  }

  CollectionReference<Map<String, dynamic>> get _addressesCollection {
    return _userDocument.collection('deliveryAddresses');
  }

  DocumentReference<Map<String, dynamic>> get _userDocument {
    return firestore!.collection('users').doc(_userId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
