import 'package:flutter_test/flutter_test.dart';

import 'package:shopping_app/features/profile/domain/models/user_profile.dart';
import 'package:shopping_app/features/profile/presentation/controllers/user_profile_controller.dart';

void main() {
  test('stores profile state locally when Firestore is unavailable', () async {
    final controller = UserProfileController();
    const profile = UserProfile(
      displayName: 'Shopper',
      fullName: 'Test Shopper',
      phoneNumber: '9999999999',
      deliveryAddress: '123 Test Street',
    );

    await controller.save(profile);

    expect(controller.profile, same(profile));
    expect(controller.successMessage, 'Profile updated.');
    expect(controller.errorMessage, isNull);
  });
}
