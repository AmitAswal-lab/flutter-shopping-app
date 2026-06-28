import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/cart_item.dart';
import '../models/payment.dart';

class CheckoutResult {
  const CheckoutResult({
    required this.orderId,
    required this.customerName,
    required this.paymentMethod,
    required this.reservationExpiresAt,
    required this.status,
    required this.totalPriceCents,
  });

  final String orderId;
  final String customerName;
  final PaymentMethod paymentMethod;
  final DateTime? reservationExpiresAt;
  final OrderStatus status;
  final int totalPriceCents;
}

class CheckoutFailure implements Exception {
  const CheckoutFailure(this.message);

  final String message;
}

class CheckoutService {
  const CheckoutService._({this.functions, this.firestore});

  factory CheckoutService.configured({required FirebaseFirestore firestore}) {
    return CheckoutService._(
      functions: FirebaseFunctions.instanceFor(region: 'us-central1'),
      firestore: firestore,
    );
  }

  const CheckoutService.unconfigured() : this._();

  final FirebaseFunctions? functions;
  final FirebaseFirestore? firestore;

  String createCheckoutId() {
    final database = firestore;
    if (database == null) {
      return DateTime.now().microsecondsSinceEpoch.toString();
    }
    return database.collection('_orderIds').doc().id;
  }

  Future<CheckoutResult> placeOrder({
    required String checkoutId,
    required String deliveryAddress,
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
  }) async {
    final callableFunctions = functions;
    if (callableFunctions == null) {
      throw const CheckoutFailure('Checkout is unavailable.');
    }

    try {
      final callable = callableFunctions.httpsCallable('placeOrder');
      final response = await callable.call(<String, Object>{
        'checkoutId': checkoutId,
        'deliveryAddress': deliveryAddress,
        'paymentMethod': paymentMethod.wireValue,
        'productIds': items.map((item) => item.productId).toList(),
      });
      final data = Map<String, dynamic>.from(response.data as Map);

      return CheckoutResult(
        orderId: data['orderId'] as String,
        customerName: data['customerName'] as String,
        paymentMethod: PaymentMethod.fromWireValue(data['paymentMethod']),
        reservationExpiresAt: _dateTimeFromMillis(
          data['reservationExpiresAtMillis'],
        ),
        status: OrderStatus.fromWireValue(data['status']),
        totalPriceCents: (data['totalPriceCents'] as num).toInt(),
      );
    } on FirebaseFunctionsException catch (error) {
      throw CheckoutFailure(
        error.message ?? 'Could not place the order. Try again.',
      );
    } on CheckoutFailure {
      rethrow;
    } catch (_) {
      throw const CheckoutFailure('Could not place the order. Try again.');
    }
  }

  DateTime? _dateTimeFromMillis(Object? value) {
    if (value is! num) return null;
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
}
