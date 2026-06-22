import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/order.dart';

class OrderHistory extends ChangeNotifier {
  final List<Order> _orders = [];

  List<Order> get orders => List.unmodifiable(_orders);
  int get count => _orders.length;
  bool get isEmpty => _orders.isEmpty;

  void add({
    required String customerName,
    required String deliveryAddress,
    required List<CartItem> items,
  }) {
    final order = Order(
      id: _createOrderId(),
      customerName: customerName,
      deliveryAddress: deliveryAddress,
      createdAt: DateTime.now(),
      items: List.unmodifiable(items),
    );

    _orders.insert(0, order);
    notifyListeners();
  }

  void clear() {
    if (_orders.isEmpty) return;

    _orders.clear();
    notifyListeners();
  }

  String _createOrderId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
