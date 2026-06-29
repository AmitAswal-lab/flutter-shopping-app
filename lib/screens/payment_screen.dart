import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../models/payment.dart';
import '../services/payment_service.dart';
import '../utils/money.dart';
import 'order_success_screen.dart';
import 'payment_result_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.customerName,
    required this.paymentMethod,
    required this.reservationExpiresAt,
    required this.totalPriceCents,
  });

  final String orderId;
  final String customerName;
  final PaymentMethod paymentMethod;
  final DateTime? reservationExpiresAt;
  final int totalPriceCents;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final Razorpay _razorpay;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _openRazorpay() async {
    if (_isResolving) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isResolving = true);

    try {
      final session = await context.read<PaymentService>().createRazorpayOrder(
        orderId: widget.orderId,
      );
      if (!mounted) return;

      setState(() => _isResolving = false);
      _razorpay.open({
        'key': session.keyId,
        'amount': session.amount,
        'currency': session.currency,
        'name': 'Shopping App',
        'description': 'Order ${session.appOrderId}',
        'order_id': session.razorpayOrderId,
        'prefill': {'email': session.email, 'name': session.customerName},
        'retry': {'enabled': true, 'max_count': 2},
        'theme': {'color': '#006C50'},
      });
    } on PaymentFailure catch (error) {
      if (!mounted) return;

      setState(() => _isResolving = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) {
    unawaited(_verifyPayment(response));
  }

  Future<void> _verifyPayment(PaymentSuccessResponse response) async {
    final paymentId = response.paymentId;
    final razorpayOrderId = response.orderId;
    final signature = response.signature;
    if (paymentId == null || razorpayOrderId == null || signature == null) {
      _showMessage('Razorpay returned an incomplete payment response.');
      return;
    }

    final navigator = Navigator.of(context);
    setState(() => _isResolving = true);

    try {
      final result = await context.read<PaymentService>().verifyRazorpayPayment(
        orderId: widget.orderId,
        razorpayOrderId: razorpayOrderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature,
      );
      if (!mounted) return;

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(
            customerName: result.customerName,
            totalPriceCents: result.totalPriceCents,
          ),
        ),
        (route) => route.isFirst,
      );
    } on PaymentFailure catch (error) {
      if (!mounted) return;

      setState(() => _isResolving = false);
      _showMessage(error.message);
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (!mounted) return;

    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      setState(() => _isResolving = false);
      _showMessage('Payment was closed. Your reservation is still active.');
      return;
    }

    unawaited(_resolveFailedPayment(response.message));
  }

  Future<void> _resolveFailedPayment(String? gatewayMessage) async {
    final navigator = Navigator.of(context);
    setState(() => _isResolving = true);

    try {
      final result = await context.read<PaymentService>().resolve(
        orderId: widget.orderId,
        outcome: PaymentOutcome.paymentFailed,
      );
      if (!mounted) return;

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => PaymentResultScreen(status: result.status),
        ),
        (route) => route.isFirst,
      );
    } on PaymentFailure catch (error) {
      if (!mounted) return;

      setState(() => _isResolving = false);
      _showMessage(gatewayMessage ?? error.message);
    }
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    final wallet = response.walletName;
    if (wallet != null) _showMessage('$wallet selected.');
  }

  Future<void> _cancelPayment() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel payment?'),
          content: const Text('The inventory reservation will be released.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep payment'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cancel payment'),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true || !mounted) return;

    final navigator = Navigator.of(context);
    setState(() => _isResolving = true);

    try {
      final result = await context.read<PaymentService>().resolve(
        orderId: widget.orderId,
        outcome: PaymentOutcome.cancelled,
      );
      if (!mounted) return;

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => PaymentResultScreen(status: result.status),
        ),
        (route) => route.isFirst,
      );
    } on PaymentFailure catch (error) {
      if (!mounted) return;

      setState(() => _isResolving = false);
      _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Payment summary', style: textTheme.titleLarge),
            const SizedBox(height: 16),
            _SummaryRow(label: 'Gateway', value: widget.paymentMethod.label),
            const SizedBox(height: 12),
            _SummaryRow(
              label: 'Amount',
              value: formatCents(widget.totalPriceCents),
            ),
            if (widget.reservationExpiresAt case final expiresAt?) ...[
              const SizedBox(height: 12),
              _SummaryRow(
                label: 'Reserved until',
                value: MaterialLocalizations.of(
                  context,
                ).formatTimeOfDay(TimeOfDay.fromDateTime(expiresAt.toLocal())),
              ),
            ],
            const Divider(height: 40),
            FilledButton.icon(
              onPressed: _isResolving ? null : _openRazorpay,
              icon: _isResolving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_outline),
              label: const Text('Pay with Razorpay'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isResolving ? null : _cancelPayment,
              child: const Text('Cancel order'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
