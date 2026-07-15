import 'package:cloud_firestore/cloud_firestore.dart';

import 'product_category.dart';

class AdminProduct {
  const AdminProduct({
    required this.id,
    required this.brand,
    required this.category,
    required this.description,
    required this.imageStoragePath,
    required this.imageUrl,
    required this.isActive,
    required this.listPriceCents,
    required this.name,
    required this.priceCents,
    required this.rating,
    required this.reviewCount,
    required this.sortOrder,
    required this.stockCount,
  });

  final String id;
  final String brand;
  final String category;
  final String description;
  final String? imageStoragePath;
  final String? imageUrl;
  final bool isActive;
  final int listPriceCents;
  final String name;
  final int priceCents;
  final double rating;
  final int reviewCount;
  final int sortOrder;
  final int stockCount;

  String get categoryLabel => productCategories[category] ?? category;

  factory AdminProduct.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AdminProduct(
      id: doc.id,
      brand: _readString(data, 'brand'),
      category: _readString(data, 'category'),
      description: _readString(data, 'description'),
      imageStoragePath: _readNullableString(data, 'imageStoragePath'),
      imageUrl: _readNullableString(data, 'imageUrl'),
      isActive: data['isActive'] != false,
      listPriceCents: _readInt(data, 'listPriceCents'),
      name: _readString(data, 'name'),
      priceCents: _readInt(data, 'priceCents'),
      rating: _readDouble(data, 'rating'),
      reviewCount: _readInt(data, 'reviewCount'),
      sortOrder: _readInt(data, 'sortOrder'),
      stockCount: _readInt(data, 'stockCount'),
    );
  }

  static String _readString(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is String ? value : '';
  }

  static String? _readNullableString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  static int _readInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is num) return value.toInt();
    return 0;
  }

  static double _readDouble(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is num) return value.toDouble();
    return 0;
  }
}
