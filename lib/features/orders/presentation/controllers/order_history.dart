import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/foundation.dart';

import 'package:shopping_app/features/cart/domain/models/cart_item.dart';
import 'package:shopping_app/features/checkout/domain/models/payment.dart';
import 'package:shopping_app/features/orders/domain/models/order.dart';
import 'package:shopping_app/features/orders/domain/models/order_status.dart';

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

  Order? orderById(String orderId) {
    for (final order in _orders) {
      if (order.id == orderId) return order;
    }
    return null;
  }

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

  CollectionReference<Map<String, dynamic>> get _ordersCollection {
    return firestore!.collection('users').doc(_userId).collection('orders');
  }

  Order _orderFromDocument(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final createdAt = data['createdAt'];
    final paidAt = data['paidAt'];
    final processingAt = data['processingAt'];
    final shippedAt = data['shippedAt'];
    final deliveredAt = data['deliveredAt'];
    final reservationExpiresAt = data['reservationExpiresAt'];
    final items = data['items'] as List<dynamic>? ?? const [];

    return Order(
      id: data['id'] as String? ?? doc.id,
      customerName: data['customerName'] as String? ?? '',
      deliveryAddress: data['deliveryAddress'] as String? ?? '',
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      paidAt: paidAt is Timestamp ? paidAt.toDate() : null,
      processingAt: processingAt is Timestamp ? processingAt.toDate() : null,
      shippedAt: shippedAt is Timestamp ? shippedAt.toDate() : null,
      deliveredAt: deliveredAt is Timestamp ? deliveredAt.toDate() : null,
      isLifecycleDemoEnabled: data['lifecycleDemoEnabled'] == true,
      items: List.unmodifiable(
        items.map((item) {
          return CartItem.fromJson(Map<String, Object?>.from(item as Map));
        }),
      ),
      paymentMethod: PaymentMethod.fromWireValue(data['paymentMethod']),
      reservationExpiresAt: reservationExpiresAt is Timestamp
          ? reservationExpiresAt.toDate()
          : null,
      status: OrderStatus.fromWireValue(data['status']),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
