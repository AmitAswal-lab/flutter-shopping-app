import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_admin/common/money.dart';

void main() {
  test('formats and parses money values', () {
    expect(formatMoney(12999), '₹129.99');
    expect(decimalToCents('129.99'), 12999);
    expect(decimalToCents('129'), 12900);
  });
}
