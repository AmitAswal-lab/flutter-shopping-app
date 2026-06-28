import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  _TestPaymentResponse _response = _TestPaymentResponse.approve;
  bool _isResolving = false;

  Future<void> _resolve(PaymentOutcome outcome) async {
    if (_isResolving) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isResolving = true);

    try {
      final result = await context.read<PaymentService>().resolve(
        orderId: widget.orderId,
        outcome: outcome,
      );
      if (!mounted) return;

      if (result.status.isSuccessful) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => OrderSuccessScreen(
              customerName: result.customerName,
              totalPriceCents: result.totalPriceCents,
            ),
          ),
          (route) => route.isFirst,
        );
        return;
      }

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => PaymentResultScreen(status: result.status),
        ),
        (route) => route.isFirst,
      );
    } on PaymentFailure catch (error) {
      if (!mounted) return;

      setState(() => _isResolving = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
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

    if (shouldCancel == true && mounted) {
      await _resolve(PaymentOutcome.cancelled);
    }
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
            _SummaryRow(label: 'Method', value: widget.paymentMethod.label),
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
            Text('Test response', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<_TestPaymentResponse>(
                segments: const [
                  ButtonSegment(
                    value: _TestPaymentResponse.approve,
                    icon: Icon(Icons.check_circle_outline),
                    label: Text('Approve'),
                  ),
                  ButtonSegment(
                    value: _TestPaymentResponse.decline,
                    icon: Icon(Icons.cancel_outlined),
                    label: Text('Decline'),
                  ),
                ],
                selected: {_response},
                onSelectionChanged: _isResolving
                    ? null
                    : (selection) {
                        setState(() => _response = selection.first);
                      },
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isResolving
                  ? null
                  : () => _resolve(
                      _response == _TestPaymentResponse.approve
                          ? PaymentOutcome.paid
                          : PaymentOutcome.paymentFailed,
                    ),
              icon: _isResolving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_outline),
              label: const Text('Complete payment'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isResolving ? null : _cancelPayment,
              child: const Text('Cancel payment'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _TestPaymentResponse { approve, decline }

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
