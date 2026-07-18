import 'package:cloud_functions/cloud_functions.dart';

class OrderCancellationFailure implements Exception {
  const OrderCancellationFailure(this.message);

  final String message;
}

class OrderRefundRefreshFailure implements Exception {
  const OrderRefundRefreshFailure(this.message);

  final String message;
}

class OrderLifecycleService {
  const OrderLifecycleService._({this.functions});

  factory OrderLifecycleService.configured() {
    return OrderLifecycleService._(
      functions: FirebaseFunctions.instanceFor(region: 'us-central1'),
    );
  }

  const OrderLifecycleService.unconfigured() : this._();

  final FirebaseFunctions? functions;

  Future<void> cancelOrder(String orderId) async {
    final callableFunctions = functions;
    if (callableFunctions == null) {
      throw const OrderCancellationFailure(
        'Order cancellation is unavailable.',
      );
    }

    try {
      final callable = callableFunctions.httpsCallable('cancelOrder');
      await callable.call(<String, Object>{'orderId': orderId});
    } on FirebaseFunctionsException catch (error) {
      throw OrderCancellationFailure(
        error.message ?? 'Could not cancel the order.',
      );
    } on OrderCancellationFailure {
      rethrow;
    } catch (_) {
      throw const OrderCancellationFailure('Could not cancel the order.');
    }
  }

  Future<void> refreshRefund(String orderId) async {
    final callableFunctions = functions;
    if (callableFunctions == null) {
      throw const OrderRefundRefreshFailure('Refund refresh is unavailable.');
    }

    try {
      final callable = callableFunctions.httpsCallable('refreshOrderRefund');
      await callable.call(<String, Object>{'orderId': orderId});
    } on FirebaseFunctionsException catch (error) {
      throw OrderRefundRefreshFailure(
        error.message ?? 'Could not refresh the refund.',
      );
    } on OrderRefundRefreshFailure {
      rethrow;
    } catch (_) {
      throw const OrderRefundRefreshFailure('Could not refresh the refund.');
    }
  }
}
