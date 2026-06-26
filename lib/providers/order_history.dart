import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/order.dart';

class OrderHistory extends ChangeNotifier {
  final FirebaseFirestore? firestore;
  final List<Order> _orders = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  String? _userId;
  bool _isLoading = false;
  String? _errorMessage;

  OrderHistory({this.firestore});

  List<Order> get orders => List.unmodifiable(_orders);
  int get count => _orders.length;
  bool get isEmpty => _orders.isEmpty;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void bindUser(String? userId) {
    if (_userId == userId) return;

    _subscription?.cancel();
    _subscription = null;
    _userId = userId;
    _orders.clear();
    _errorMessage = null;

    if (firestore == null || userId == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _subscription = _ordersCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            _orders
              ..clear()
              ..addAll(snapshot.docs.map(_orderFromDocument));
            _isLoading = false;
            _errorMessage = null;
            notifyListeners();
          },
          onError: (_) {
            _isLoading = false;
            _errorMessage = 'Could not load order history.';
            notifyListeners();
          },
        );
  }

  Future<void> add({
    required String customerName,
    required String deliveryAddress,
    required List<CartItem> items,
  }) async {
    final order = Order(
      id: _createOrderId(),
      customerName: customerName,
      deliveryAddress: deliveryAddress,
      createdAt: DateTime.now(),
      items: List.unmodifiable(items),
    );

    if (!_isFirestoreReady) {
      _orders.insert(0, order);
      notifyListeners();
      return;
    }

    await _ordersCollection.doc(order.id).set({
      'id': order.id,
      'customerName': order.customerName,
      'deliveryAddress': order.deliveryAddress,
      'createdAt': Timestamp.fromDate(order.createdAt),
      'items': order.items.map((item) => item.toJson()).toList(),
    });
  }

  Future<void> clear() async {
    if (!_isFirestoreReady) {
      _clearLocally();
      return;
    }

    final snapshot = await _ordersCollection.get();
    if (snapshot.docs.isEmpty) return;

    final batch = firestore!.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  bool get _isFirestoreReady => firestore != null && _userId != null;

  CollectionReference<Map<String, dynamic>> get _ordersCollection {
    return firestore!.collection('users').doc(_userId).collection('orders');
  }

  Order _orderFromDocument(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final createdAt = data['createdAt'];
    final items = data['items'] as List<dynamic>? ?? const [];

    return Order(
      id: data['id'] as String? ?? doc.id,
      customerName: data['customerName'] as String? ?? '',
      deliveryAddress: data['deliveryAddress'] as String? ?? '',
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      items: List.unmodifiable(
        items.map((item) {
          return CartItem.fromJson(Map<String, Object?>.from(item as Map));
        }),
      ),
    );
  }

  void _clearLocally() {
    if (_orders.isEmpty) return;

    _orders.clear();
    notifyListeners();
  }

  String _createOrderId() {
    if (_isFirestoreReady) return _ordersCollection.doc().id;

    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
