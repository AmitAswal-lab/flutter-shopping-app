enum ProductCategory {
  all('All'),
  audio('Audio'),
  wearable('Wearable'),
  accessory('Accessory');

  final String label;

  const ProductCategory(this.label);
}

class Product {
  final String id;
  final String brand;
  final String name;
  final String description;
  final int priceCents;
  final int listPriceCents;
  final String imageAsset;
  final ProductCategory category;
  final double rating;
  final int reviewCount;
  final int stockCount;

  const Product({
    required this.id,
    required this.brand,
    required this.name,
    required this.description,
    required this.priceCents,
    required this.listPriceCents,
    required this.imageAsset,
    required this.category,
    required this.rating,
    required this.reviewCount,
    required this.stockCount,
  });

  bool get inStock => stockCount > 0;

  int get discountPercent {
    if (listPriceCents <= priceCents) return 0;
    return ((listPriceCents - priceCents) * 100 / listPriceCents).round();
  }

  factory Product.fromJson(String id, Map<String, dynamic> json) {
    return Product(
      id: id,
      brand: _readString(json, 'brand'),
      name: _readString(json, 'name'),
      description: _readString(json, 'description'),
      priceCents: _readInt(json, 'priceCents'),
      listPriceCents: _readInt(json, 'listPriceCents'),
      imageAsset: _readString(json, 'imageAsset'),
      category: _readCategory(json['category']),
      rating: _readDouble(json, 'rating'),
      reviewCount: _readInt(json, 'reviewCount'),
      stockCount: _readInt(json, 'stockCount'),
    );
  }

  Map<String, Object> toJson() {
    return {
      'brand': brand,
      'name': name,
      'description': description,
      'priceCents': priceCents,
      'listPriceCents': listPriceCents,
      'imageAsset': imageAsset,
      'category': category.name,
      'rating': rating,
      'reviewCount': reviewCount,
      'stockCount': stockCount,
    };
  }

  static String _readString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.isNotEmpty) return value;
    throw FormatException('Product field "$key" must be a non-empty string.');
  }

  static int _readInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) return value.toInt();
    throw FormatException('Product field "$key" must be a number.');
  }

  static double _readDouble(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) return value.toDouble();
    throw FormatException('Product field "$key" must be a number.');
  }

  static ProductCategory _readCategory(Object? value) {
    if (value is! String) {
      throw const FormatException('Product field "category" must be a string.');
    }

    return ProductCategory.values.firstWhere(
      (category) => category != ProductCategory.all && category.name == value,
      orElse: () {
        throw FormatException('Unknown product category "$value".');
      },
    );
  }
}
