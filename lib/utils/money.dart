String formatCents(int cents) {
  final dollars = cents ~/ 100;
  final remainder = (cents % 100).toString().padLeft(2, '0');
  return '\$$dollars.$remainder';
}
