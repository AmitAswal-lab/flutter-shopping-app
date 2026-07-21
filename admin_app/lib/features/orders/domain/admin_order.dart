import 'package:cloud_firestore/cloud_firestore.dart';

class AdminOrder {
  const AdminOrder({
    required this.id,
    required this.userId,
    required this.customerName,
    required this.deliveryAddress,
    required this.deliveryPhoneNumber,
    required this.deliveryRecipient,
    required this.createdAt,
    required this.items,
    required this.paymentMethod,
    required this.paymentProvider,
    required this.razorpayPaymentId,
    required this.status,
    required this.totalPriceCents,
  });

  final String id;
  final String userId;
  final String customerName;
  final String deliveryAddress;
  final String deliveryPhoneNumber;
  final String deliveryRecipient;
  final DateTime createdAt;
  final List<AdminOrderItem> items;
  final String paymentMethod;
  final String paymentProvider;
  final String? razorpayPaymentId;
  final String status;
  final int totalPriceCents;

  int get itemCount =>
      items.fold(0, (itemTotal, item) => itemTotal + item.quantity);

  bool get _usesRazorpay =>
      paymentProvider == 'razorpay' || paymentMethod == 'razorpay';

  bool get _hasCaptureReference =>
      razorpayPaymentId?.trim().isNotEmpty ?? false;

  String get paymentLabel => switch (status) {
    'pendingPayment' => 'Payment pending',
    'paymentFailed' => 'Payment failed',
    'expired' => 'Payment reservation expired',
    'confirmed' => 'Payment verification required',
    'paid' || 'processing' || 'shipped' || 'delivered'
        when _usesRazorpay && !_hasCaptureReference =>
      'Razorpay capture reference missing',
    'paid' ||
    'processing' ||
    'shipped' ||
    'delivered' when _usesRazorpay => 'Razorpay payment captured',
    'paid' ||
    'processing' ||
    'shipped' ||
    'delivered' => 'Payment recorded as captured',
    'cancelled' when _hasCaptureReference =>
      'Captured payment — check refund status',
    'cancelled' => 'No captured payment recorded',
    _ => 'Payment status unknown',
  };

  String? get nextFulfillmentAction => switch (status) {
    'paid' when !_usesRazorpay || _hasCaptureReference =>
      'Start preparing order',
    'processing' => 'Mark as shipped',
    'shipped' => 'Mark as delivered',
    _ => null,
  };

  String? get fulfillmentConfirmation => switch (status) {
    'paid' =>
      'This records the order as Preparing. Confirm that preparation has actually started.',
    'processing' =>
      'This records the order as Shipped. Confirm that the package has been handed to the carrier.',
    'shipped' =>
      'This records the order as Delivered. Confirm that delivery has been verified; this cannot be undone here.',
    _ => null,
  };

  factory AdminOrder.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final createdAt = data['createdAt'];
    final rawItems = data['items'];
    final userId = doc.reference.parent.parent?.id;

    return AdminOrder(
      id: doc.id,
      userId: userId ?? '',
      customerName: _readString(data, 'customerName', fallback: 'Shopper'),
      deliveryAddress: _readString(data, 'deliveryAddress'),
      deliveryPhoneNumber: _readString(data, 'deliveryPhoneNumber'),
      deliveryRecipient: _readString(data, 'deliveryRecipient'),
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      items: rawItems is List
          ? List.unmodifiable(
              rawItems.whereType<Map>().map(
                (item) =>
                    AdminOrderItem.fromMap(Map<String, dynamic>.from(item)),
              ),
            )
          : const [],
      paymentMethod: _readString(data, 'paymentMethod'),
      paymentProvider: _readString(data, 'paymentProvider'),
      razorpayPaymentId: _readOptionalString(data, 'razorpayPaymentId'),
      status: _readString(data, 'status'),
      totalPriceCents: _readInt(data, 'totalPriceCents'),
    );
  }

  static String _readString(
    Map<String, dynamic> data,
    String key, {
    String fallback = '',
  }) {
    final value = data[key];
    return value is String && value.isNotEmpty ? value : fallback;
  }

  static String? _readOptionalString(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  static int _readInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is num ? value.toInt() : 0;
  }
}

class AdminOrderItem {
  const AdminOrderItem({
    required this.name,
    required this.priceCents,
    required this.quantity,
  });

  final String name;
  final int priceCents;
  final int quantity;

  int get lineTotalCents => priceCents * quantity;

  factory AdminOrderItem.fromMap(Map<String, dynamic> data) {
    final name = data['name'];
    final priceCents = data['priceCents'];
    final quantity = data['quantity'];
    return AdminOrderItem(
      name: name is String && name.isNotEmpty ? name : 'Product',
      priceCents: priceCents is num ? priceCents.toInt() : 0,
      quantity: quantity is num ? quantity.toInt() : 0,
    );
  }
}
