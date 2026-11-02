import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'alarm_coordinator.dart';

class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  void Function(String groupId)? _onOpenGroup;
  String? _initialGroupId;

  String? takeInitialGroupId() {
    final value = _initialGroupId;
    _initialGroupId = null;
    return value;
  }

  Future<void> initialize({void Function(String groupId)? onOpenGroup}) async {
    _onOpenGroup = onOpenGroup;
    await _tokenSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    _tokenSubscription = _messaging.onTokenRefresh.listen(
      (token) => unawaited(
        _register(token).catchError((Object error, StackTrace stackTrace) {
          debugPrint('FCM token refresh registration failed: $error');
        }),
      ),
    );
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _openMessage,
    );
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      final groupId = message.data['groupId'];
      final notification = message.notification;
      if (groupId is String &&
          notification != null &&
          defaultTargetPlatform == TargetPlatform.android) {
        unawaited(
          AlarmCoordinator.instance.showForegroundGroupNotification(
            title: notification.title ?? 'Namaz Grubum',
            body: notification.body ?? 'Yeni bir grup hatırlatman var.',
            groupId: groupId,
          ),
        );
      }
    });
    final initialMessage = await _messaging.getInitialMessage();
    final initialGroup = initialMessage?.data['groupId'];
    if (initialGroup is String && initialGroup.isNotEmpty) {
      _initialGroupId = initialGroup;
    }

    final settings = await _messaging.getNotificationSettings();
    if (_canReceiveNotifications(settings.authorizationStatus)) {
      await _registerCurrentToken();
    }
  }

  void _openMessage(RemoteMessage message) {
    final groupId = message.data['groupId'];
    if (groupId is String && groupId.isNotEmpty) _onOpenGroup?.call(groupId);
  }

  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (!_canReceiveNotifications(settings.authorizationStatus)) {
        throw StateError('Bildirim izni verilmedi.');
      }
    }
    await syncEnabledPreference(enabled);
    if (enabled) await _registerCurrentToken();
    await AlarmCoordinator.instance.setLocalNotificationsEnabled(enabled);
  }

  Future<void> syncEnabledPreference(bool enabled) async {
    await _functions.httpsCallable('setNotificationsEnabled').call(
      <String, Object>{'enabled': enabled},
    );
  }

  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return _canReceiveNotifications(settings.authorizationStatus);
  }

  Future<bool> requestPermissionAndRegister() async {
    if (!await requestPermission()) return false;
    await _registerCurrentToken();
    return true;
  }

  bool _canReceiveNotifications(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

  Future<void> _registerCurrentToken() async {
    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) await _register(token);
  }

  Future<void> _register(String token) async {
    if (FirebaseAuth.instance.currentUser == null) return;
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
    if (platform == null) return;
    await _functions.httpsCallable('registerDevice').call(<String, Object>{
      'token': token,
      'platform': platform,
    });
  }
}
