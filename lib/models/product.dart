class Product {
  final String id;
  final String name;
  final int priceCents;
  final String emoji;

  const Product({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.emoji,
  });
}

const List<Product> kProducts = [
  Product(id: 'p1', name: 'Wireless Headphones', priceCents: 7999, emoji: '🎧'),
  Product(id: 'p2', name: 'Smart Watch', priceCents: 12999, emoji: '⌚'),
  Product(id: 'p3', name: 'Bluetooth Speaker', priceCents: 4999, emoji: '🔊'),
  Product(id: 'p4', name: 'Gaming Mouse', priceCents: 2999, emoji: '🖱️'),
];
