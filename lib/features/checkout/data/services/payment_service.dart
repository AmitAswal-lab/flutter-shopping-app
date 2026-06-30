import 'package:cloud_functions/cloud_functions.dart';

import 'package:shopping_app/features/checkout/domain/models/payment.dart';
import 'package:shopping_app/features/orders/domain/models/order_status.dart';

class PaymentResult {
  const PaymentResult({
    required this.orderId,
    required this.customerName,
    required this.paymentMethod,
    required this.status,
    required this.totalPriceCents,
  });

  final String orderId;
  final String customerName;
  final PaymentMethod paymentMethod;
  final OrderStatus status;
  final int totalPriceCents;
}

class RazorpayCheckoutSession {
  const RazorpayCheckoutSession({
    required this.amount,
    required this.appOrderId,
    required this.currency,
    required this.customerName,
    required this.email,
    required this.keyId,
    required this.razorpayOrderId,
  });

  final int amount;
  final String appOrderId;
  final String currency;
  final String customerName;
  final String email;
  final String keyId;
  final String razorpayOrderId;
}

class PaymentFailure implements Exception {
  const PaymentFailure(this.message);

  final String message;
}

class PaymentService {
  const PaymentService._({this.functions});

  factory PaymentService.configured() {
    return PaymentService._(
      functions: FirebaseFunctions.instanceFor(region: 'us-central1'),
    );
  }

  const PaymentService.unconfigured() : this._();

  final FirebaseFunctions? functions;

  Future<RazorpayCheckoutSession> createRazorpayOrder({
    required String orderId,
  }) async {
    final callableFunctions = _requireFunctions();

    try {
      final callable = callableFunctions.httpsCallable('createRazorpayOrder');
      final response = await callable.call(<String, Object>{
        'orderId': orderId,
      });
      final data = Map<String, dynamic>.from(response.data as Map);

      return RazorpayCheckoutSession(
        amount: (data['amount'] as num).toInt(),
        appOrderId: data['orderId'] as String,
        currency: data['currency'] as String,
        customerName: data['customerName'] as String,
        email: data['email'] as String? ?? '',
        keyId: data['keyId'] as String,
        razorpayOrderId: data['razorpayOrderId'] as String,
      );
    } on FirebaseFunctionsException catch (error) {
      throw PaymentFailure(
        error.message ?? 'Could not start Razorpay Checkout. Try again.',
      );
    } on PaymentFailure {
      rethrow;
    } catch (_) {
      throw const PaymentFailure(
        'Could not start Razorpay Checkout. Try again.',
      );
    }
  }

  Future<PaymentResult> verifyRazorpayPayment({
    required String orderId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final callableFunctions = _requireFunctions();

    try {
      final callable = callableFunctions.httpsCallable('verifyRazorpayPayment');
      final response = await callable.call(<String, Object>{
        'orderId': orderId,
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
      });
      return _paymentResultFrom(response.data);
    } on FirebaseFunctionsException catch (error) {
      throw PaymentFailure(
        error.message ?? 'Could not verify payment. Try again.',
      );
    } on PaymentFailure {
      rethrow;
    } catch (_) {
      throw const PaymentFailure('Could not verify payment. Try again.');
    }
  }

  Future<PaymentResult> resolve({
    required String orderId,
    required PaymentOutcome outcome,
  }) async {
    final callableFunctions = _requireFunctions();

    try {
      final callable = callableFunctions.httpsCallable('resolvePayment');
      final response = await callable.call(<String, Object>{
        'orderId': orderId,
        'outcome': outcome.wireValue,
      });
      return _paymentResultFrom(response.data);
    } on FirebaseFunctionsException catch (error) {
      throw PaymentFailure(
        error.message ?? 'Could not complete payment. Try again.',
      );
    } on PaymentFailure {
      rethrow;
    } catch (_) {
      throw const PaymentFailure('Could not complete payment. Try again.');
    }
  }

  FirebaseFunctions _requireFunctions() {
    final callableFunctions = functions;
    if (callableFunctions == null) {
      throw const PaymentFailure('Payment is unavailable.');
    }
    return callableFunctions;
  }

  PaymentResult _paymentResultFrom(Object? value) {
    final data = Map<String, dynamic>.from(value as Map);
    return PaymentResult(
      orderId: data['orderId'] as String,
      customerName: data['customerName'] as String,
      paymentMethod: PaymentMethod.fromWireValue(data['paymentMethod']),
      status: OrderStatus.fromWireValue(data['status']),
      totalPriceCents: (data['totalPriceCents'] as num).toInt(),
    );
  }
}
