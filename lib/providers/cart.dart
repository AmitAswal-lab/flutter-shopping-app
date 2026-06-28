import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';

class CartStockException implements Exception {
  const CartStockException({
    required this.productName,
    required this.availableQuantity,
  });

  final String productName;
  final int availableQuantity;

  String get message => availableQuantity <= 0
      ? '$productName is out of stock.'
      : 'Only $availableQuantity $productName available.';
}

class Cart extends ChangeNotifier {
  final FirebaseFirestore? firestore;
  final List<CartItem> _items = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  String? _userId;
  bool _isLoading = false;
  String? _errorMessage;

  Cart({this.firestore});

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get totalCount => _items.fold(0, (total, item) => total + item.quantity);

  int get totalPriceCents =>
      _items.fold(0, (total, item) => total + item.lineTotalCents);

  int quantityOf(String productId) {
    final index = _items.indexWhere((e) => e.productId == productId);
    return index < 0 ? 0 : _items[index].quantity;
  }

  void bindUser(String? userId) {
    if (_userId == userId) return;

    _subscription?.cancel();
    _subscription = null;
    _userId = userId;
    _items.clear();
    _errorMessage = null;

    if (firestore == null || userId == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _subscription = _itemsCollection
        .orderBy('name')
        .snapshots()
        .listen(
          (snapshot) {
            _items
              ..clear()
              ..addAll(
                snapshot.docs.map((doc) {
                  final data = Map<String, Object?>.from(doc.data());
                  data['productId'] ??= doc.id;
                  return CartItem.fromJson(data);
                }),
              );
            _isLoading = false;
            _errorMessage = null;
            notifyListeners();
          },
          onError: (_) {
            _isLoading = false;
            _errorMessage = 'Could not load cart.';
            notifyListeners();
          },
        );
  }

  Future<void> add(CartItem item, {required int availableStock}) async {
    if (!_isFirestoreReady) {
      _addLocally(item, availableStock: availableStock);
      return;
    }

    final doc = _itemsCollection.doc(item.productId);
    await firestore!.runTransaction((transaction) async {
      final snapshot = await transaction.get(doc);
      final existingQuantity = snapshot.exists
          ? (snapshot.data()?['quantity'] as num? ?? 0).toInt()
          : 0;
      final nextQuantity = existingQuantity + item.quantity;
      _ensureStockAvailable(
        productName: item.name,
        quantity: nextQuantity,
        availableStock: availableStock,
      );
      final nextItem = item.copyWith(quantity: nextQuantity);

      transaction.set(doc, {
        ...nextItem.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> remove(String productId) async {
    if (!_isFirestoreReady) {
      _removeLocally(productId);
      return;
    }

    await _itemsCollection.doc(productId).delete();
  }

  Future<void> setQuantity(
    String productId,
    int quantity, {
    required int availableStock,
  }) async {
    if (!_isFirestoreReady) {
      _setQuantityLocally(productId, quantity, availableStock: availableStock);
      return;
    }

    if (quantity <= 0) {
      await remove(productId);
      return;
    }

    final item = _items
        .where((item) => item.productId == productId)
        .firstOrNull;
    if (item == null) return;
    if (quantity > item.quantity) {
      _ensureStockAvailable(
        productName: item.name,
        quantity: quantity,
        availableStock: availableStock,
      );
    }

    await _itemsCollection.doc(productId).update({
      'quantity': quantity,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

  bool get _isFirestoreReady => firestore != null && _userId != null;

  CollectionReference<Map<String, dynamic>> get _itemsCollection {
    return firestore!.collection('users').doc(_userId).collection('cartItems');
  }

  void _addLocally(CartItem item, {required int availableStock}) {
    final index = _items.indexWhere((e) => e.productId == item.productId);
    final nextQuantity = index >= 0
        ? _items[index].quantity + item.quantity
        : item.quantity;
    _ensureStockAvailable(
      productName: item.name,
      quantity: nextQuantity,
      availableStock: availableStock,
    );

    if (index >= 0) {
      _items[index] = _items[index].copyWith(quantity: nextQuantity);
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void _removeLocally(String productId) {
    final before = _items.length;
    _items.removeWhere((e) => e.productId == productId);
    if (_items.length != before) notifyListeners();
  }

  void _setQuantityLocally(
    String productId,
    int quantity, {
    required int availableStock,
  }) {
    final index = _items.indexWhere((e) => e.productId == productId);
    if (index < 0) return;
    if (quantity <= 0) {
      _removeLocally(productId);
      return;
    }
    if (quantity > _items[index].quantity) {
      _ensureStockAvailable(
        productName: _items[index].name,
        quantity: quantity,
        availableStock: availableStock,
      );
    }
    _items[index] = _items[index].copyWith(quantity: quantity);
    notifyListeners();
  }

  void _ensureStockAvailable({
    required String productName,
    required int quantity,
    required int availableStock,
  }) {
    if (quantity <= availableStock) return;

    throw CartStockException(
      productName: productName,
      availableQuantity: availableStock,
    );
  }

  void _clearLocally() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
