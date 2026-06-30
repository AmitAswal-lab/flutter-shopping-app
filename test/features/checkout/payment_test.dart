import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_app/features/checkout/domain/models/payment.dart';
import 'package:shopping_app/features/orders/domain/models/order.dart';

void main() {
  group('Payment models', () {
    test('maps stored payment and order values', () {
      expect(PaymentMethod.fromWireValue('razorpay'), PaymentMethod.razorpay);
      expect(
        OrderStatus.fromWireValue('pendingPayment'),
        OrderStatus.pendingPayment,
      );
    });

    test('keeps legacy confirmed orders successful', () {
      final status = OrderStatus.fromWireValue('confirmed');

      expect(status, OrderStatus.confirmed);
      expect(status.isSuccessful, isTrue);
    });

    test('allows an unexpired pending payment to resume', () {
      final order = _pendingOrder(
        DateTime.now().add(const Duration(minutes: 5)),
      );

      expect(order.canResumePayment, isTrue);
    });

    test('does not allow an expired payment to resume', () {
      final order = _pendingOrder(
        DateTime.now().subtract(const Duration(minutes: 1)),
      );

      expect(order.canResumePayment, isFalse);
    });
  });
}

Order _pendingOrder(DateTime expiresAt) {
  return Order(
    id: 'order_123',
    customerName: 'Shopper',
    deliveryAddress: '123 Test Street',
    createdAt: DateTime.now(),
    items: const [],
    paymentMethod: PaymentMethod.razorpay,
    reservationExpiresAt: expiresAt,
    status: OrderStatus.pendingPayment,
  );
}
