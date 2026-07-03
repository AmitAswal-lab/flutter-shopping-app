import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  NotificationService.configured({
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _messaging = messaging ?? FirebaseMessaging.instance;

  NotificationService.unconfigured() : _firestore = null, _messaging = null;

  static const _installationIdKey = 'notification_installation_id';

  final FirebaseFirestore? _firestore;
  final FirebaseMessaging? _messaging;
  final _foregroundMessages = StreamController<RemoteMessage>.broadcast();
  final _openedMessages = StreamController<RemoteMessage>.broadcast();

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  String? _installationId;
  String? _userId;
  bool _didInitializeListeners = false;

  Stream<RemoteMessage> get foregroundMessages => _foregroundMessages.stream;
  Stream<RemoteMessage> get openedMessages => _openedMessages.stream;

  Future<void> bindUser(String? userId) async {
    if (_userId == userId) return;
    _userId = userId;

    if (userId == null || _messaging == null || _firestore == null) return;

    await _initializeListeners();
    await _requestPermissionAndRegister();
  }

  Future<void> unregisterCurrentInstallation() async {
    final firestore = _firestore;
    final messaging = _messaging;
    final userId = _userId;
    _userId = null;

    if (firestore == null || messaging == null || userId == null) return;

    try {
      final installationId = await _getInstallationId();
      await _registrationDocument(userId, installationId).delete();
    } catch (error) {
      debugPrint('Could not remove notification registration: $error');
    }

    try {
      await messaging.deleteToken();
    } catch (error) {
      debugPrint('Could not delete notification token: $error');
    }
  }

  Future<void> _initializeListeners() async {
    if (_didInitializeListeners) return;
    _didInitializeListeners = true;

    await _messaging!.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _foregroundMessages.add,
    );
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _openedMessages.add,
    );
    _tokenSubscription = _messaging.onTokenRefresh.listen(_saveToken);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _openedMessages.add(initialMessage);
    }
  }

  Future<void> _requestPermissionAndRegister() async {
    try {
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final hasApnsToken = await _waitForApnsToken();
        if (!hasApnsToken) return;
      }

      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) await _saveToken(token);
    } catch (error) {
      debugPrint('Could not configure notifications: $error');
    }
  }

  Future<bool> _waitForApnsToken() async {
    for (var attempt = 0; attempt < 10; attempt += 1) {
      if (await _messaging!.getAPNSToken() != null) return true;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  Future<void> _saveToken(String token) async {
    final userId = _userId;
    if (userId == null || _firestore == null) return;

    try {
      final installationId = await _getInstallationId();
      final registration = _registrationDocument(userId, installationId);
      final existing = await registration.get();

      await registration.set({
        if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
        'platform': _platformName,
        'token': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('Could not save notification registration: $error');
    }
  }

  Future<String> _getInstallationId() async {
    final existing = _installationId;
    if (existing != null) return existing;

    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_installationIdKey);
    if (stored != null && stored.isNotEmpty) {
      _installationId = stored;
      return stored;
    }

    final random = Random.secure().nextInt(0x7fffffff);
    final generated =
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
        '${random.toRadixString(36)}';
    await preferences.setString(_installationIdKey, generated);
    _installationId = generated;
    return generated;
  }

  DocumentReference<Map<String, dynamic>> _registrationDocument(
    String userId,
    String installationId,
  ) {
    return _firestore!
        .collection('users')
        .doc(userId)
        .collection('deviceRegistrations')
        .doc(installationId);
  }

  String get _platformName {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'unsupported',
    };
  }

  void dispose() {
    _foregroundSubscription?.cancel();
    _openedSubscription?.cancel();
    _tokenSubscription?.cancel();
    _foregroundMessages.close();
    _openedMessages.close();
  }
}
