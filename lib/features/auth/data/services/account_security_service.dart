import 'package:cloud_functions/cloud_functions.dart';

class AccountSecurityFailure implements Exception {
  final String message;

  const AccountSecurityFailure(this.message);
}

class AccountSecurityService {
  const AccountSecurityService._({this.functions});

  factory AccountSecurityService.configured() {
    return AccountSecurityService._(
      functions: FirebaseFunctions.instanceFor(region: 'us-central1'),
    );
  }

  const AccountSecurityService.unconfigured() : this._();

  final FirebaseFunctions? functions;

  Future<void> deleteAccount() async {
    final callableFunctions = functions;
    if (callableFunctions == null) {
      throw const AccountSecurityFailure('Firebase is not configured yet.');
    }

    try {
      await callableFunctions.httpsCallable('deleteAccount').call<void>();
    } on FirebaseFunctionsException catch (error) {
      throw AccountSecurityFailure(
        error.message ?? 'Could not delete the account. Please try again.',
      );
    } catch (_) {
      throw const AccountSecurityFailure(
        'Could not delete the account. Please try again.',
      );
    }
  }
}
