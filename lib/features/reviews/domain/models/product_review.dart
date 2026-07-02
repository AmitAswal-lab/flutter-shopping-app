import 'package:cloud_firestore/cloud_firestore.dart';

class ProductReview {
  const ProductReview({
    required this.userId,
    required this.displayName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  final String userId;
  final String displayName;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ProductReview.fromJson(String userId, Map<String, dynamic> json) {
    final createdAt = json['createdAt'];
    final updatedAt = json['updatedAt'];
    return ProductReview(
      userId: userId,
      displayName: json['displayName'] as String? ?? 'Shopper',
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String? ?? '',
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: updatedAt is Timestamp
          ? updatedAt.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
