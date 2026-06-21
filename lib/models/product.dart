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
  final String name;
  final int priceCents;
  final String imageAsset;
  final ProductCategory category;

  const Product({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.imageAsset,
    required this.category,
  });
}

const List<Product> kProducts = [
  Product(
    id: 'p1',
    name: 'Wireless Headphones',
    priceCents: 7999,
    imageAsset: 'assets/products/wireless_headphones.png',
    category: ProductCategory.audio,
  ),
  Product(
    id: 'p2',
    name: 'Smart Watch',
    priceCents: 12999,
    imageAsset: 'assets/products/smart_watch.png',
    category: ProductCategory.wearable,
  ),
  Product(
    id: 'p3',
    name: 'Bluetooth Speaker',
    priceCents: 4999,
    imageAsset: 'assets/products/bluetooth_speaker.png',
    category: ProductCategory.audio,
  ),
  Product(
    id: 'p4',
    name: 'Gaming Mouse',
    priceCents: 2999,
    imageAsset: 'assets/products/gaming_mouse.png',
    category: ProductCategory.accessory,
  ),
];
