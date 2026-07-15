import 'package:cloud_functions/cloud_functions.dart';

class ReviewFailure implements Exception {
  const ReviewFailure(this.message);

  final String message;
}

class ReviewService {
  const ReviewService._({this.functions});

  factory ReviewService.configured() {
    return ReviewService._(
      functions: FirebaseFunctions.instanceFor(region: 'us-central1'),
    );
  }

  const ReviewService.unconfigured() : this._();

  final FirebaseFunctions? functions;

  Future<void> submit({
    required String productId,
    required int rating,
    required String comment,
  }) async {
    await _call('submitProductReview', {
      'productId': productId,
      'rating': rating,
      'comment': comment,
    });
  }

  Future<void> delete(String productId) async {
    await _call('deleteProductReview', {'productId': productId});
  }

  Future<void> _call(String name, Map<String, Object> data) async {
    final callableFunctions = functions;
    if (callableFunctions == null) {
      throw const ReviewFailure('Reviews are unavailable.');
    }

    try {
      await callableFunctions.httpsCallable(name).call(data);
    } on FirebaseFunctionsException catch (error) {
      throw ReviewFailure(error.message ?? 'Could not update your review.');
    } catch (_) {
      throw const ReviewFailure('Could not update your review.');
    }
  }
}
