import 'cart_item.dart';

class Order {
  final String id;
  final String customerName;
  final String deliveryAddress;
  final DateTime createdAt;
  final List<CartItem> items;

  const Order({
    required this.id,
    required this.customerName,
    required this.deliveryAddress,
    required this.createdAt,
    required this.items,
  });

  int get totalCount => items.fold(0, (sum, item) => sum + item.quantity);

  int get totalPriceCents =>
      items.fold(0, (sum, item) => sum + item.lineTotalCents);
}
