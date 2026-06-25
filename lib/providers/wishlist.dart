import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/product.dart';

class Wishlist extends ChangeNotifier {
  final FirebaseFirestore? firestore;
  final Set<String> _productIds = <String>{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  String? _userId;
  bool _isLoading = false;
  String? _errorMessage;

  Wishlist({this.firestore});

  Set<String> get productIds => Set.unmodifiable(_productIds);
  int get count => _productIds.length;
  bool get isEmpty => _productIds.isEmpty;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool isFavorite(String productId) {
    return _productIds.contains(productId);
  }

  void bindUser(String? userId) {
    if (_userId == userId) return;

    _subscription?.cancel();
    _subscription = null;
    _userId = userId;
    _productIds.clear();
    _errorMessage = null;

    if (firestore == null || userId == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _subscription = _itemsCollection.snapshots().listen(
      (snapshot) {
        _productIds
          ..clear()
          ..addAll(snapshot.docs.map((doc) => doc.id));
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (_) {
        _isLoading = false;
        _errorMessage = 'Could not load wishlist.';
        notifyListeners();
      },
    );
  }

  Future<void> toggle(String productId) async {
    if (!_isFirestoreReady) {
      _toggleLocally(productId);
      return;
    }

    if (_productIds.contains(productId)) {
      await _itemsCollection.doc(productId).delete();
    } else {
      await _itemsCollection.doc(productId).set({
        'productId': productId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> remove(String productId) async {
    if (!_isFirestoreReady) {
      _removeLocally(productId);
      return;
    }

    await _itemsCollection.doc(productId).delete();
  }

  Future<void> clear() async {
    if (!_isFirestoreReady) {
      _clearLocally();
      return;
    }

    final snapshot = await _itemsCollection.get();
    if (snapshot.docs.isEmpty) return;

    final batch = firestore!.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  List<Product> favoritesFrom(List<Product> products) {
    return products
        .where((product) => _productIds.contains(product.id))
        .toList(growable: false);
  }

  bool get _isFirestoreReady => firestore != null && _userId != null;

  CollectionReference<Map<String, dynamic>> get _itemsCollection {
    return firestore!
        .collection('users')
        .doc(_userId)
        .collection('wishlistItems');
  }

  void _toggleLocally(String productId) {
    if (_productIds.contains(productId)) {
      _productIds.remove(productId);
    } else {
      _productIds.add(productId);
    }

    notifyListeners();
  }

  void _removeLocally(String productId) {
    if (!_productIds.remove(productId)) return;

    notifyListeners();
  }

  void _clearLocally() {
    if (_productIds.isEmpty) return;

    _productIds.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
