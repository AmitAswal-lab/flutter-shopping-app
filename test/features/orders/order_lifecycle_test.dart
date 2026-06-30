import 'package:flutter_test/flutter_test.dart';

import 'package:shopping_app/features/checkout/domain/models/payment.dart';
import 'package:shopping_app/features/orders/domain/models/order.dart';
import 'package:shopping_app/features/orders/domain/models/order_status.dart';

void main() {
  group('Order lifecycle', () {
    test('maps fulfillment statuses from Firestore values', () {
      expect(OrderStatus.fromWireValue('processing'), OrderStatus.processing);
      expect(OrderStatus.fromWireValue('shipped'), OrderStatus.shipped);
      expect(OrderStatus.fromWireValue('delivered'), OrderStatus.delivered);
    });

    test('treats fulfillment states as successful orders', () {
      expect(OrderStatus.paid.isSuccessful, isTrue);
      expect(OrderStatus.processing.isSuccessful, isTrue);
      expect(OrderStatus.shipped.isSuccessful, isTrue);
      expect(OrderStatus.delivered.isSuccessful, isTrue);
      expect(OrderStatus.paymentFailed.isSuccessful, isFalse);
    });

    test('reports ordered fulfillment progress', () {
      expect(OrderStatus.paid.fulfillmentStep, 0);
      expect(OrderStatus.processing.fulfillmentStep, 1);
      expect(OrderStatus.shipped.fulfillmentStep, 2);
      expect(OrderStatus.delivered.fulfillmentStep, 3);
      expect(OrderStatus.cancelled.fulfillmentStep, -1);
    });

    test('returns stored timestamps for timeline milestones', () {
      final createdAt = DateTime(2026, 6, 30, 10);
      final paidAt = DateTime(2026, 6, 30, 10, 1);
      final processingAt = DateTime(2026, 6, 30, 11);
      final order = Order(
        id: 'order_123',
        customerName: 'Shopper',
        deliveryAddress: '123 Test Street',
        createdAt: createdAt,
        paidAt: paidAt,
        processingAt: processingAt,
        items: const [],
        paymentMethod: PaymentMethod.razorpay,
        reservationExpiresAt: null,
        status: OrderStatus.processing,
      );

      expect(order.timestampFor(OrderStatus.paid), paidAt);
      expect(order.timestampFor(OrderStatus.processing), processingAt);
      expect(order.timestampFor(OrderStatus.shipped), isNull);
    });

    test('uses created time for legacy confirmed orders', () {
      final createdAt = DateTime(2026, 6, 30, 10);
      final order = Order(
        id: 'legacy_order',
        customerName: 'Shopper',
        deliveryAddress: '123 Test Street',
        createdAt: createdAt,
        items: const [],
        paymentMethod: PaymentMethod.razorpay,
        reservationExpiresAt: null,
        status: OrderStatus.confirmed,
      );

      expect(order.timestampFor(OrderStatus.paid), createdAt);
      expect(order.status.hasFulfillmentProgress, isTrue);
    });
  });
}
