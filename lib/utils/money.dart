String formatCents(int cents) {
  final rupees = cents ~/ 100;
  final remainder = (cents % 100).toString().padLeft(2, '0');
  return '₹$rupees.$remainder';
}
