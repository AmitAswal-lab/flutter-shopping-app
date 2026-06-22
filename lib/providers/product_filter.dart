import 'package:flutter/foundation.dart';

import '../models/product.dart';

class ProductFilter extends ChangeNotifier {
  String _query = '';
  ProductCategory _category = ProductCategory.all;

  String get query => _query;
  ProductCategory get category => _category;
  bool get hasActiveFilters =>
      _query.isNotEmpty || _category != ProductCategory.all;

  void setQuery(String value) {
    final nextQuery = value.trim().toLowerCase();
    if (_query == nextQuery) return;

    _query = nextQuery;
    notifyListeners();
  }

  void setCategory(ProductCategory value) {
    if (_category == value) return;

    _category = value;
    notifyListeners();
  }

  void clear() {
    if (!hasActiveFilters) return;

    _query = '';
    _category = ProductCategory.all;
    notifyListeners();
  }

  List<Product> applyTo(List<Product> products) {
    return products
        .where((product) {
          final searchableText = '${product.name} ${product.category.label}'
              .toLowerCase();
          final matchesQuery =
              _query.isEmpty || searchableText.contains(_query);
          final matchesCategory =
              _category == ProductCategory.all || product.category == _category;

          return matchesQuery && matchesCategory;
        })
        .toList(growable: false);
  }
}
