class UserProfile {
  final String displayName;
  final String fullName;
  final String phoneNumber;
  final String deliveryAddress;
  final bool deliveryAddressMigrated;

  const UserProfile({
    required this.displayName,
    required this.fullName,
    required this.phoneNumber,
    required this.deliveryAddress,
    this.deliveryAddressMigrated = false,
  });

  const UserProfile.empty()
    : displayName = '',
      fullName = '',
      phoneNumber = '',
      deliveryAddress = '',
      deliveryAddressMigrated = false;

  bool get hasDeliveryDetails {
    return fullName.trim().isNotEmpty || deliveryAddress.trim().isNotEmpty;
  }

  Map<String, Object?> toJson() {
    return {
      'displayName': displayName.trim(),
      'fullName': fullName.trim(),
      'phoneNumber': phoneNumber.trim(),
      'deliveryAddress': deliveryAddress.trim(),
      'deliveryAddressMigrated': deliveryAddressMigrated,
    };
  }

  factory UserProfile.fromJson(Map<String, Object?> json) {
    return UserProfile(
      displayName: json['displayName'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      deliveryAddress: json['deliveryAddress'] as String? ?? '',
      deliveryAddressMigrated:
          json['deliveryAddressMigrated'] as bool? ?? false,
    );
  }
}
