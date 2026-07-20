import 'package:flutter/foundation.dart';

import 'package:shopping_app/features/catalog/domain/models/product.dart';

enum ProductSort {
  featured('Featured'),
  priceLowToHigh('Price: low to high'),
  priceHighToLow('Price: high to low'),
  highestRated('Highest rated');

  const ProductSort(this.label);

  final String label;
}

class ProductFilter extends ChangeNotifier {
  String _query = '';
  ProductCategory _category = ProductCategory.all;
  ProductSort _sort = ProductSort.featured;

  String get query => _query;
  ProductCategory get category => _category;
  ProductSort get sort => _sort;
  bool get hasActiveFilters =>
      _query.isNotEmpty ||
      _category != ProductCategory.all ||
      _sort != ProductSort.featured;

  void setQuery(String value) {
    final nextQuery = value.trim();
    if (_query == nextQuery) return;

    _query = nextQuery;
    notifyListeners();
  }

  void setCategory(ProductCategory value) {
    if (_category == value) return;

    _category = value;
    notifyListeners();
  }

  void setSort(ProductSort value) {
    if (_sort == value) return;

    _sort = value;
    notifyListeners();
  }

  void clear() {
    if (!hasActiveFilters) return;

    _query = '';
    _category = ProductCategory.all;
    _sort = ProductSort.featured;
    notifyListeners();
  }

  List<Product> applyTo(List<Product> products) {
    final filteredProducts = products
        .where((product) {
          final searchableText =
              '${product.brand} ${product.name} ${product.description} ${product.category.label}'
                  .toLowerCase();
          final matchesQuery =
              _query.isEmpty || searchableText.contains(_query.toLowerCase());
          final matchesCategory =
              _category == ProductCategory.all || product.category == _category;

          return matchesQuery && matchesCategory;
        })
        .toList(growable: false);

    switch (_sort) {
      case ProductSort.featured:
        return filteredProducts;
      case ProductSort.priceLowToHigh:
        return _sortProducts(
          filteredProducts,
          (first, second) => first.priceCents.compareTo(second.priceCents),
        );
      case ProductSort.priceHighToLow:
        return _sortProducts(
          filteredProducts,
          (first, second) => second.priceCents.compareTo(first.priceCents),
        );
      case ProductSort.highestRated:
        return _sortProducts(filteredProducts, (first, second) {
          final ratingComparison = second.rating.compareTo(first.rating);
          if (ratingComparison != 0) return ratingComparison;
          return second.reviewCount.compareTo(first.reviewCount);
        });
    }
  }

  List<Product> _sortProducts(
    List<Product> products,
    int Function(Product first, Product second) compare,
  ) {
    final sortedProducts = List<Product>.of(products)
      ..sort((first, second) {
        final primaryComparison = compare(first, second);
        if (primaryComparison != 0) return primaryComparison;

        return first.name.toLowerCase().compareTo(second.name.toLowerCase());
      });

    return List.unmodifiable(sortedProducts);
  }
}
