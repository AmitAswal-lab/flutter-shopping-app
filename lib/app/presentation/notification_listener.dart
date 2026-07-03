import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/app/presentation/app_navigation.dart';
import 'package:shopping_app/features/notifications/data/services/notification_service.dart';
import 'package:shopping_app/features/orders/presentation/screens/order_detail_screen.dart';

class AppNotificationListener extends StatefulWidget {
  const AppNotificationListener({super.key, required this.child});

  final Widget child;

  @override
  State<AppNotificationListener> createState() =>
      _AppNotificationListenerState();
}

class _AppNotificationListenerState extends State<AppNotificationListener> {
  NotificationService? _service;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final service = context.read<NotificationService>();
    if (_service == service) return;

    _foregroundSubscription?.cancel();
    _openedSubscription?.cancel();
    _service = service;
    _foregroundSubscription = service.foregroundMessages.listen(
      _showForegroundMessage,
    );
    _openedSubscription = service.openedMessages.listen(_openMessage);
  }

  @override
  void dispose() {
    _foregroundSubscription?.cancel();
    _openedSubscription?.cancel();
    super.dispose();
  }

  void _showForegroundMessage(RemoteMessage message) {
    final messenger = AppNavigation.scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    final title = message.notification?.title ?? 'Order update';
    final body = message.notification?.body;
    final orderId = _orderId(message);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(body == null || body.isEmpty ? title : '$title\n$body'),
          action: orderId == null
              ? null
              : SnackBarAction(
                  label: 'View',
                  onPressed: () => _openOrder(orderId),
                ),
        ),
      );
  }

  void _openMessage(RemoteMessage message) {
    final orderId = _orderId(message);
    if (orderId != null) _openOrder(orderId);
  }

  String? _orderId(RemoteMessage message) {
    if (message.data['type'] != 'orderStatus') return null;
    final orderId = message.data['orderId'];
    return orderId == null || orderId.isEmpty ? null : orderId;
  }

  Future<void> _openOrder(String orderId) async {
    for (var attempt = 0; attempt < 10; attempt += 1) {
      final navigator = AppNavigation.navigatorKey.currentState;
      if (navigator != null) {
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: orderId),
          ),
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
