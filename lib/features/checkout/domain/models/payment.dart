enum PaymentMethod {
  razorpay('razorpay', 'Razorpay Test Mode');

  const PaymentMethod(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static PaymentMethod fromWireValue(Object? value) {
    return PaymentMethod.values.firstWhere(
      (method) => method.wireValue == value,
      orElse: () => PaymentMethod.razorpay,
    );
  }
}

enum PaymentOutcome {
  paymentFailed('paymentFailed'),
  cancelled('cancelled');

  const PaymentOutcome(this.wireValue);

  final String wireValue;
}
