import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/product.dart';

class ProductCatalog extends ChangeNotifier {
  ProductCatalog({required this.firestore}) {
    unawaited(load());
  }

  final FirebaseFirestore? firestore;
  final List<Product> _products = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  bool _isLoading = false;
  bool _isSeeding = false;
  String? _errorMessage;

  List<Product> get products => List.unmodifiable(_products);
  bool get isLoading => _isLoading;
  bool get isSeeding => _isSeeding;
  String? get errorMessage => _errorMessage;

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

    _subscription = firestore!
        .collection('products')
        .orderBy('sortOrder')
        .snapshots()
        .listen(_handleSnapshot, onError: _handleError);
  }

  Future<void> seedSampleProducts() async {
    if (!kDebugMode) {
      throw StateError('Sample products can only be seeded in debug mode.');
    }
    if (firestore == null || _isSeeding) return;

    _isSeeding = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final source = await rootBundle.loadString(
        'assets/data/products_seed.json',
      );
      final records = jsonDecode(source) as List<dynamic>;
      final batch = firestore!.batch();

      for (final record in records) {
        final data = Map<String, dynamic>.from(record as Map);
        final id = data.remove('id') as String;
        batch.set(firestore!.collection('products').doc(id), {
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (_) {
      _errorMessage = 'Could not add the sample product catalog.';
    } finally {
      _isSeeding = false;
      notifyListeners();
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

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
