import 'package:shopping_app/features/cart/domain/models/cart_item.dart';
import 'package:shopping_app/features/checkout/domain/models/payment.dart';

class Order {
  final String id;
  final String customerName;
  final String deliveryAddress;
  final DateTime createdAt;
  final List<CartItem> items;
  final PaymentMethod paymentMethod;
  final DateTime? reservationExpiresAt;
  final OrderStatus status;

  const Order({
    required this.id,
    required this.customerName,
    required this.deliveryAddress,
    required this.createdAt,
    required this.items,
    required this.paymentMethod,
    required this.reservationExpiresAt,
    required this.status,
  });

  int get totalCount => items.fold(0, (sum, item) => sum + item.quantity);

  int get totalPriceCents =>
      items.fold(0, (sum, item) => sum + item.lineTotalCents);

  bool get canResumePayment {
    if (!status.isPending) return false;
    final expiresAt = reservationExpiresAt;
    return expiresAt == null || expiresAt.isAfter(DateTime.now());
  }
}
