class DeliveryAddress {
  const DeliveryAddress({
    required this.id,
    required this.label,
    required this.fullName,
    required this.phoneNumber,
    required this.address,
    required this.isDefault,
  });

  final String id;
  final String label;
  final String fullName;
  final String phoneNumber;
  final String address;
  final bool isDefault;

  String get summary => address.replaceAll(RegExp(r'\s+'), ' ').trim();

  String get formattedAddress {
    final recipient = fullName.trim();
    final phone = phoneNumber.trim();
    final lines = <String>[if (recipient.isNotEmpty) recipient, address.trim()];
    if (phone.isNotEmpty) lines.add(phone);
    return lines.join('\n');
  }

  DeliveryAddress copyWith({
    String? id,
    String? label,
    String? fullName,
    String? phoneNumber,
    String? address,
    bool? isDefault,
  }) {
    return DeliveryAddress(
      id: id ?? this.id,
      label: label ?? this.label,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  factory DeliveryAddress.fromJson(String id, Map<String, Object?> json) {
    return DeliveryAddress(
      id: id,
      label: json['label'] as String? ?? 'Address',
      fullName: json['fullName'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      address: json['address'] as String? ?? '',
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}
