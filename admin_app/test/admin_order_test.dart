import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_admin/features/orders/domain/admin_order.dart';

void main() {
  group('AdminOrder payment state', () {
    test('does not call an unverified confirmed order paid', () {
      final order = _order(status: 'confirmed');

      expect(order.paymentLabel, 'Payment verification required');
      expect(order.nextFulfillmentAction, isNull);
      expect(order.fulfillmentConfirmation, isNull);
    });

    test('flags a missing Razorpay capture reference', () {
      final order = _order(status: 'paid');

      expect(order.paymentLabel, 'Razorpay capture reference missing');
      expect(order.nextFulfillmentAction, isNull);
    });

    test('shows captured only when the Razorpay reference is stored', () {
      final order = _order(status: 'paid', razorpayPaymentId: 'pay_123');

      expect(order.paymentLabel, 'Razorpay payment captured');
      expect(order.fulfillmentConfirmation, contains('Preparing'));
    });
  });
}

AdminOrder _order({required String status, String? razorpayPaymentId}) {
  return AdminOrder(
    id: 'order_123',
    userId: 'alice',
    customerName: 'Alice',
    deliveryAddress: '123 Test Street',
    deliveryPhoneNumber: '1234567890',
    deliveryRecipient: 'Alice',
    createdAt: DateTime(2026),
    items: const [],
    paymentMethod: 'razorpay',
    paymentProvider: razorpayPaymentId == null ? '' : 'razorpay',
    razorpayPaymentId: razorpayPaymentId,
    status: status,
    totalPriceCents: 7999,
  );
}
