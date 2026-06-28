enum PaymentMethod {
  testCard('testCard', 'Test card'),
  testUpi('testUpi', 'Test UPI');

  const PaymentMethod(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static PaymentMethod fromWireValue(Object? value) {
    return PaymentMethod.values.firstWhere(
      (method) => method.wireValue == value,
      orElse: () => PaymentMethod.testCard,
    );
  }
}

enum PaymentOutcome {
  paid('paid'),
  paymentFailed('paymentFailed'),
  cancelled('cancelled');

  const PaymentOutcome(this.wireValue);

  final String wireValue;
}

enum OrderStatus {
  pendingPayment('pendingPayment', 'Payment pending'),
  paid('paid', 'Paid'),
  paymentFailed('paymentFailed', 'Payment failed'),
  cancelled('cancelled', 'Cancelled'),
  expired('expired', 'Payment expired'),
  confirmed('confirmed', 'Confirmed');

  const OrderStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  bool get isPending => this == OrderStatus.pendingPayment;
  bool get isSuccessful =>
      this == OrderStatus.paid || this == OrderStatus.confirmed;

  static OrderStatus fromWireValue(Object? value) {
    return OrderStatus.values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => OrderStatus.confirmed,
    );
  }
}
