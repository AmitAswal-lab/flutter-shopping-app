import 'package:flutter/foundation.dart';

import 'cart_item.dart';

class Cart extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get totalCount => _items.fold(0, (sum, item) => sum + item.quantity);

  int get totalPriceCents =>
      _items.fold(0, (sum, item) => sum + item.lineTotalCents);

  int quantityOf(String productId) {
    final index = _items.indexWhere((e) => e.productId == productId);
    return index < 0 ? 0 : _items[index].quantity;
  }

  void add(CartItem item) {
    final index = _items.indexWhere((e) => e.productId == item.productId);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(
        quantity: _items[index].quantity + item.quantity,
      );
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void remove(String productId) {
    final before = _items.length;
    _items.removeWhere((e) => e.productId == productId);
    if (_items.length != before) notifyListeners();
  }

  void setQuantity(String productId, int quantity) {
    final index = _items.indexWhere((e) => e.productId == productId);
    if (index < 0) return;
    if (quantity <= 0) {
      remove(productId);
      return;
    }
    _items[index] = _items[index].copyWith(quantity: quantity);
    notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }
}
