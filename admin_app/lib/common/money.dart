String formatMoney(int cents) => '₹${centsToDecimal(cents)}';

String centsToDecimal(int cents) {
  final rupees = cents ~/ 100;
  final paise = cents % 100;
  return '$rupees.${paise.toString().padLeft(2, '0')}';
}

int decimalToCents(String value) {
  final parts = value.trim().split('.');
  final rupees = int.parse(parts.first);
  final paise = parts.length == 1 ? '0' : parts[1].padRight(2, '0');
  return rupees * 100 + int.parse(paise);
}

String? moneyValidator(String? value) {
  if (value == null || value.trim().isEmpty) return 'Required';
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value.trim())) {
    return 'Use 99 or 99.99';
  }
  return null;
}

String? integerValidator(String? value) {
  if (value == null || int.tryParse(value.trim()) == null) {
    return 'Enter a whole number';
  }
  if (int.parse(value.trim()) < 0) return 'Cannot be negative';
  return null;
}

String? requiredText(String? value) {
  if (value == null || value.trim().isEmpty) return 'Required';
  return null;
}
