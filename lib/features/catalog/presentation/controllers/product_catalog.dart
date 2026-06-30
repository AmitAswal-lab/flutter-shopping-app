import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:shopping_app/features/catalog/domain/models/product.dart';

class ProductCatalog extends ChangeNotifier {
  ProductCatalog({required this.firestore}) {
    unawaited(load());
  }

  final FirebaseFirestore? firestore;
  final List<Product> _products = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  bool _isLoading = false;
  String? _errorMessage;

  List<Product> get products => List.unmodifiable(_products);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Product? productById(String productId) {
    for (final product in _products) {
      if (product.id == productId) return product;
    }
    return null;
  }

  Future<void> load() async {
    await _subscription?.cancel();
    _subscription = null;
    _products.clear();
    _errorMessage = null;

    if (firestore == null) {
      _isLoading = false;
      _errorMessage = 'Product catalog is unavailable.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _subscription = _productsQuery.snapshots().listen(
      _handleSnapshot,
      onError: _handleError,
    );
  }

  Future<void> refreshFromServer() async {
    if (firestore == null) {
      throw StateError('Product catalog is unavailable.');
    }

    try {
      final snapshot = await _productsQuery.get(
        const GetOptions(source: Source.server),
      );
      _handleSnapshot(snapshot);
    } catch (_) {
      _errorMessage = 'Could not verify current product stock.';
      notifyListeners();
      rethrow;
    }
  }

  void _handleSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    try {
      final products = snapshot.docs
          .where((doc) => doc.data()['isActive'] != false)
          .map((doc) => Product.fromJson(doc.id, doc.data()))
          .toList(growable: false);

      _products
        ..clear()
        ..addAll(products);
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } on FormatException {
      _products.clear();
      _isLoading = false;
      _errorMessage = 'Some product data is invalid.';
      notifyListeners();
    }
  }

  void _handleError(Object _) {
    _isLoading = false;
    _errorMessage = 'Could not load products. Try again.';
    notifyListeners();
  }

  Query<Map<String, dynamic>> get _productsQuery {
    return firestore!.collection('products').orderBy('sortOrder');
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
