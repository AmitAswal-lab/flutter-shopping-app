import 'package:shopping_app/features/cart/domain/models/cart_item.dart';
import 'package:shopping_app/features/checkout/domain/models/payment.dart';
import 'package:shopping_app/features/orders/domain/models/order_status.dart';

class Order {
  final String id;
  final String customerName;
  final String deliveryAddress;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? processingAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final DateTime? refundCreatedAt;
  final DateTime? refundProcessedAt;
  final bool isLifecycleDemoEnabled;
  final List<CartItem> items;
  final PaymentMethod paymentMethod;
  final DateTime? reservationExpiresAt;
  final OrderStatus status;
  final OrderRefundStatus refundStatus;
  final String? refundId;
  final int? refundAmountCents;

  const Order({
    required this.id,
    required this.customerName,
    required this.deliveryAddress,
    required this.createdAt,
    this.paidAt,
    this.processingAt,
    this.shippedAt,
    this.deliveredAt,
    this.cancelledAt,
    this.refundCreatedAt,
    this.refundProcessedAt,
    this.isLifecycleDemoEnabled = false,
    required this.items,
    required this.paymentMethod,
    required this.reservationExpiresAt,
    required this.status,
    this.refundStatus = OrderRefundStatus.notRequired,
    this.refundId,
    this.refundAmountCents,
  });

  int get totalCount => items.fold(0, (sum, item) => sum + item.quantity);

  int get totalPriceCents =>
      items.fold(0, (sum, item) => sum + item.lineTotalCents);

  bool get canResumePayment {
    if (!status.isPending) return false;
    final expiresAt = reservationExpiresAt;
    return expiresAt == null || expiresAt.isAfter(DateTime.now());
  }

  DateTime? timestampFor(OrderStatus milestone) {
    return switch (milestone) {
      OrderStatus.paid || OrderStatus.confirmed => paidAt ?? createdAt,
      OrderStatus.processing => processingAt,
      OrderStatus.shipped => shippedAt,
      OrderStatus.delivered => deliveredAt,
      _ => null,
    };
  }
}

enum OrderRefundStatus {
  notRequired('notRequired'),
  initiating('initiating'),
  pending('pending'),
  processed('processed'),
  failed('failed');

  const OrderRefundStatus(this.wireValue);

  final String wireValue;

  static OrderRefundStatus fromWireValue(Object? value) {
    return OrderRefundStatus.values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => OrderRefundStatus.notRequired,
    );
  }
}
