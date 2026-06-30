enum OrderStatus {
  pendingPayment('pendingPayment', 'Payment pending'),
  paid('paid', 'Paid'),
  processing('processing', 'Processing'),
  shipped('shipped', 'Shipped'),
  delivered('delivered', 'Delivered'),
  paymentFailed('paymentFailed', 'Payment failed'),
  cancelled('cancelled', 'Cancelled'),
  expired('expired', 'Payment expired'),
  confirmed('confirmed', 'Confirmed');

  const OrderStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  bool get isPending => this == OrderStatus.pendingPayment;

  bool get isSuccessful {
    return switch (this) {
      OrderStatus.paid ||
      OrderStatus.processing ||
      OrderStatus.shipped ||
      OrderStatus.delivered ||
      OrderStatus.confirmed => true,
      _ => false,
    };
  }

  bool get hasFulfillmentProgress {
    return switch (this) {
      OrderStatus.paid ||
      OrderStatus.processing ||
      OrderStatus.shipped ||
      OrderStatus.delivered ||
      OrderStatus.confirmed => true,
      _ => false,
    };
  }

  bool get canAdvanceFulfillmentDemo {
    return switch (this) {
      OrderStatus.paid ||
      OrderStatus.confirmed ||
      OrderStatus.processing ||
      OrderStatus.shipped => true,
      _ => false,
    };
  }

  int get fulfillmentStep {
    return switch (this) {
      OrderStatus.paid || OrderStatus.confirmed => 0,
      OrderStatus.processing => 1,
      OrderStatus.shipped => 2,
      OrderStatus.delivered => 3,
      _ => -1,
    };
  }

  static OrderStatus fromWireValue(Object? value) {
    return OrderStatus.values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => OrderStatus.confirmed,
    );
  }
}
