import 'package:cloud_functions/cloud_functions.dart';

class OrderLifecycleFailure implements Exception {
  const OrderLifecycleFailure(this.message);

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

  Future<void> startDemo(String orderId) async {
    final callableFunctions = functions;
    if (callableFunctions == null) {
      throw const OrderLifecycleFailure('Order simulation is unavailable.');
    }

    try {
      final callable = callableFunctions.httpsCallable(
        'startOrderLifecycleDemo',
      );
      await callable.call(<String, Object>{'orderId': orderId});
    } on FirebaseFunctionsException catch (error) {
      throw OrderLifecycleFailure(
        error.message ?? 'Could not start the order simulation.',
      );
    } on OrderLifecycleFailure {
      rethrow;
    } catch (_) {
      throw const OrderLifecycleFailure(
        'Could not start the order simulation.',
      );
    }
  }
}
