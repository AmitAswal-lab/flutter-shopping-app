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
}

const List<Product> kProducts = [
  Product(
    id: 'p1',
    brand: 'Auralux',
    name: 'Wireless Headphones',
    description:
        'Comfortable over-ear headphones with balanced sound and long battery life for daily listening.',
    priceCents: 7999,
    listPriceCents: 11999,
    imageAsset: 'assets/products/wireless_headphones.png',
    category: ProductCategory.audio,
    rating: 4.6,
    reviewCount: 128,
    stockCount: 18,
  ),
  Product(
    id: 'p2',
    brand: 'PulseFit',
    name: 'Smart Watch',
    description:
        'A lightweight smartwatch for notifications, workouts, heart-rate tracking, and everyday wear.',
    priceCents: 12999,
    listPriceCents: 17999,
    imageAsset: 'assets/products/smart_watch.png',
    category: ProductCategory.wearable,
    rating: 4.5,
    reviewCount: 94,
    stockCount: 12,
  ),
  Product(
    id: 'p3',
    brand: 'Bassline',
    name: 'Bluetooth Speaker',
    description:
        'Portable speaker with room-filling audio, compact build, and easy wireless pairing.',
    priceCents: 4999,
    listPriceCents: 7999,
    imageAsset: 'assets/products/bluetooth_speaker.png',
    category: ProductCategory.audio,
    rating: 4.4,
    reviewCount: 76,
    stockCount: 24,
  ),
  Product(
    id: 'p4',
    brand: 'ClickForge',
    name: 'Gaming Mouse',
    description:
        'Responsive gaming mouse with programmable controls, textured grip, and smooth tracking.',
    priceCents: 2999,
    listPriceCents: 4999,
    imageAsset: 'assets/products/gaming_mouse.png',
    category: ProductCategory.accessory,
    rating: 4.7,
    reviewCount: 153,
    stockCount: 31,
  ),
  Product(
    id: 'p5',
    brand: 'Auralux',
    name: 'Studio Headphones',
    description:
        'Closed-back headphones tuned for focused work, editing, and immersive listening sessions.',
    priceCents: 9999,
    listPriceCents: 14999,
    imageAsset: 'assets/products/wireless_headphones.png',
    category: ProductCategory.audio,
    rating: 4.8,
    reviewCount: 87,
    stockCount: 9,
  ),
  Product(
    id: 'p6',
    brand: 'PulseFit',
    name: 'Fitness Watch',
    description:
        'Workout-friendly watch with activity goals, sleep insights, and a bright daily-use display.',
    priceCents: 8999,
    listPriceCents: 12999,
    imageAsset: 'assets/products/smart_watch.png',
    category: ProductCategory.wearable,
    rating: 4.3,
    reviewCount: 61,
    stockCount: 15,
  ),
  Product(
    id: 'p7',
    brand: 'Bassline',
    name: 'Mini Speaker',
    description:
        'Small wireless speaker made for desks, travel bags, and casual listening around the house.',
    priceCents: 3499,
    listPriceCents: 5999,
    imageAsset: 'assets/products/bluetooth_speaker.png',
    category: ProductCategory.audio,
    rating: 4.2,
    reviewCount: 48,
    stockCount: 22,
  ),
  Product(
    id: 'p8',
    brand: 'ClickForge',
    name: 'Ergonomic Mouse',
    description:
        'Comfort-focused mouse with quiet clicks and a sculpted shape for long work sessions.',
    priceCents: 2499,
    listPriceCents: 3999,
    imageAsset: 'assets/products/gaming_mouse.png',
    category: ProductCategory.accessory,
    rating: 4.4,
    reviewCount: 72,
    stockCount: 27,
  ),
  Product(
    id: 'p9',
    brand: 'Auralux',
    name: 'Travel Headphones',
    description:
        'Foldable headphones with soft cushions and reliable wireless playback for commutes.',
    priceCents: 6999,
    listPriceCents: 9999,
    imageAsset: 'assets/products/wireless_headphones.png',
    category: ProductCategory.audio,
    rating: 4.1,
    reviewCount: 39,
    stockCount: 16,
  ),
  Product(
    id: 'p10',
    brand: 'PulseFit',
    name: 'Everyday Watch',
    description:
        'Simple wearable for time, notifications, step goals, and quick glanceable updates.',
    priceCents: 7499,
    listPriceCents: 10999,
    imageAsset: 'assets/products/smart_watch.png',
    category: ProductCategory.wearable,
    rating: 4.0,
    reviewCount: 44,
    stockCount: 19,
  ),
  Product(
    id: 'p11',
    brand: 'Bassline',
    name: 'Home Speaker',
    description:
        'Compact home speaker built for podcasts, playlists, and richer sound in small rooms.',
    priceCents: 5999,
    listPriceCents: 8999,
    imageAsset: 'assets/products/bluetooth_speaker.png',
    category: ProductCategory.audio,
    rating: 4.5,
    reviewCount: 83,
    stockCount: 13,
  ),
  Product(
    id: 'p12',
    brand: 'ClickForge',
    name: 'Precision Mouse',
    description:
        'Lightweight accessory with precise tracking for productivity, design work, and gaming.',
    priceCents: 3999,
    listPriceCents: 6499,
    imageAsset: 'assets/products/gaming_mouse.png',
    category: ProductCategory.accessory,
    rating: 4.6,
    reviewCount: 96,
    stockCount: 20,
  ),
];
