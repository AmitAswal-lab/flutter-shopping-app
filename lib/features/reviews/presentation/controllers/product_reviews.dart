import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:shopping_app/features/reviews/domain/models/product_review.dart';

class ProductReviews extends ChangeNotifier {
  ProductReviews({required this.firestore});

  final FirebaseFirestore? firestore;
  final List<ProductReview> _reviews = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  String? _productId;
  String? _userId;
  bool _isLoading = false;
  String? _errorMessage;

  List<ProductReview> get reviews => List.unmodifiable(_reviews);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ProductReview? get currentUserReview {
    final userId = _userId;
    if (userId == null) return null;
    for (final review in _reviews) {
      if (review.userId == userId) return review;
    }
    return null;
  }

  void bindProduct({required String productId, required String? userId}) {
    if (_productId == productId && _userId == userId) return;

    _subscription?.cancel();
    _productId = productId;
    _userId = userId;
    _reviews.clear();
    _errorMessage = null;

    if (firestore == null || userId == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();
    _listen();
  }

  void retry() {
    if (firestore == null || _productId == null || _isLoading) return;
    _subscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    _listen();
  }

  void unbindProduct(String productId) {
    if (_productId != productId) return;
    _subscription?.cancel();
    _subscription = null;
    _productId = null;
    _userId = null;
    _reviews.clear();
    _isLoading = false;
    _errorMessage = null;
  }

  void _listen() {
    _subscription = firestore!
        .collection('products')
        .doc(_productId)
        .collection('reviews')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            _reviews
              ..clear()
              ..addAll(
                snapshot.docs.map(
                  (doc) => ProductReview.fromJson(doc.id, doc.data()),
                ),
              );
            _isLoading = false;
            _errorMessage = null;
            notifyListeners();
          },
          onError: (_) {
            _isLoading = false;
            _errorMessage = 'Could not load reviews.';
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
