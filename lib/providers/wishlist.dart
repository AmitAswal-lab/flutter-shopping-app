import 'package:flutter/foundation.dart';

import '../models/product.dart';

class Wishlist extends ChangeNotifier {
  final Set<String> _productIds = <String>{};

  Set<String> get productIds => Set.unmodifiable(_productIds);
  int get count => _productIds.length;
  bool get isEmpty => _productIds.isEmpty;

  bool isFavorite(String productId) {
    return _productIds.contains(productId);
  }

  void toggle(String productId) {
    if (_productIds.contains(productId)) {
      _productIds.remove(productId);
    } else {
      _productIds.add(productId);
    }

    notifyListeners();
  }

  void remove(String productId) {
    if (!_productIds.remove(productId)) return;

    notifyListeners();
  }

  void clear() {
    if (_productIds.isEmpty) return;

    _productIds.clear();
    notifyListeners();
  }

  List<Product> favoritesFrom(List<Product> products) {
    return products
        .where((product) => _productIds.contains(product.id))
        .toList(growable: false);
  }
}
