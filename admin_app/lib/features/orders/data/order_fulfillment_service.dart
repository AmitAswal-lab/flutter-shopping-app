import 'package:cloud_functions/cloud_functions.dart';

import '../domain/admin_order.dart';

class OrderFulfillmentFailure implements Exception {
  const OrderFulfillmentFailure(this.message);

  final String message;
}

class OrderFulfillmentService {
  OrderFulfillmentService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<void> advance(AdminOrder order) async {
    try {
      await _functions.httpsCallable('advanceOrderFulfillment').call(
        <String, Object>{'orderId': order.id, 'userId': order.userId},
      );
    } on FirebaseFunctionsException catch (error) {
      throw OrderFulfillmentFailure(
        error.code == 'failed-precondition'
            ? 'This order was already updated. Close and reopen it to see the latest status.'
            : error.message ?? 'Could not update this order.',
      );
    } catch (_) {
      throw const OrderFulfillmentFailure('Could not update this order.');
    }
  }
}
