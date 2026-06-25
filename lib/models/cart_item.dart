class CartItem {
  final String productId;
  final String name;
  final int priceCents;
  final int quantity;

  const CartItem({
    required this.productId,
    required this.name,
    required this.priceCents,
    required this.quantity,
  });

  int get lineTotalCents => priceCents * quantity;

  CartItem copyWith({int? quantity}) {
    return CartItem(
      productId: productId,
      name: name,
      priceCents: priceCents,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'productId': productId,
      'name': name,
      'priceCents': priceCents,
      'quantity': quantity,
    };
  }

  factory CartItem.fromJson(Map<String, Object?> json) {
    return CartItem(
      productId: json['productId'] as String,
      name: json['name'] as String,
      priceCents: json['priceCents'] as int,
      quantity: json['quantity'] as int,
    );
  }
}
