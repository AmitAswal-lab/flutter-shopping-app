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
}
