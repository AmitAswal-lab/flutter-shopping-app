import 'package:cloud_functions/cloud_functions.dart';

import '../models/payment.dart';

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

  Future<PaymentResult> resolve({
    required String orderId,
    required PaymentOutcome outcome,
  }) async {
    final callableFunctions = functions;
    if (callableFunctions == null) {
      throw const PaymentFailure('Payment is unavailable.');
    }

    try {
      final callable = callableFunctions.httpsCallable('resolvePayment');
      final response = await callable.call(<String, Object>{
        'orderId': orderId,
        'outcome': outcome.wireValue,
      });
      final data = Map<String, dynamic>.from(response.data as Map);

      return PaymentResult(
        orderId: data['orderId'] as String,
        customerName: data['customerName'] as String,
        paymentMethod: PaymentMethod.fromWireValue(data['paymentMethod']),
        status: OrderStatus.fromWireValue(data['status']),
        totalPriceCents: (data['totalPriceCents'] as num).toInt(),
      );
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
}
