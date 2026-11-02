import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_coordinator.dart';
import 'push_notification_service.dart';
import 'offline_action_queue.dart';
import 'prayer_schedule_sync_service.dart';

class AppSessionController extends ChangeNotifier with WidgetsBindingObserver {
  AppSessionController._();

  static final instance = AppSessionController._();

  StreamSubscription<User?>? _authSubscription;
  int _revision = 0;
  bool _initialized = false;
  bool _onboardingComplete = false;
  bool _accountSuspended = false;
  String? _userId;
  void Function(String groupId)? _onOpenGroup;
  DateTime? _lastResumeRefresh;

  bool get initialized => _initialized;
  bool get onboardingComplete => _onboardingComplete;
  bool get accountSuspended => _accountSuspended;
  String? get userId => _userId;

  Future<void> initialize({
    required void Function(String groupId) onOpenGroup,
  }) async {
    _onOpenGroup = onOpenGroup;
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.addObserver(this);
    if (Firebase.apps.isEmpty) {
      _initialized = true;
      notifyListeners();
      return;
    }

    await _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) => unawaited(_configureUser(user)),
    );
    await refreshForCurrentUser();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_onboardingComplete) return;
    final last = _lastResumeRefresh;
    if (last != null && DateTime.now().difference(last).inMinutes < 15) return;
    _lastResumeRefresh = DateTime.now();
    unawaited(_refreshPrayerServices());
  }

  Future<void> _refreshPrayerServices() async {
    try {
      await PrayerScheduleSyncService.instance.sync();
      await AlarmCoordinator.instance.initialize(onOpenGroup: _onOpenGroup);
    } catch (error) {
      debugPrint('Prayer services resume refresh failed: $error');
    }
  }

  Future<void> refreshForCurrentUser() =>
      _configureUser(FirebaseAuth.instance.currentUser);

  Future<void> markOnboardingComplete() async {
    if (Firebase.apps.isEmpty) {
      _onboardingComplete = true;
      _initialized = true;
      notifyListeners();
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_preferenceKey(user.uid), true);
    await FirebaseFirestore.instance
        .doc('users/${user.uid}')
        .set(<String, Object?>{
          'onboardingCompleted': true,
          'onboardingCompletedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    _userId = user.uid;
    _onboardingComplete = true;
    _initialized = true;
    notifyListeners();
  }

  Future<void> clearCompletion({String? forUserId}) async {
    final userId = forUserId ?? _userId;
    if (userId != null) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_preferenceKey(userId));
    }
    _onboardingComplete = false;
    notifyListeners();
  }

  Future<void> restartOnboarding() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await clearCompletion(forUserId: user.uid);
    await FirebaseFirestore.instance.doc('users/${user.uid}').set(
      <String, Object?>{
        'onboardingCompleted': false,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _configureUser(User? initialUser) async {
    final revision = ++_revision;
    _initialized = false;
    notifyListeners();

    var user = initialUser;
    user ??= (await FirebaseAuth.instance.signInAnonymously()).user;
    if (user == null || revision != _revision) return;

    final reference = FirebaseFirestore.instance.doc('users/${user.uid}');
    var snapshot = await reference.get();
    if (!snapshot.exists) {
      final now = FieldValue.serverTimestamp();
      await reference.set(<String, Object?>{
        'displayName': 'Misafir',
        'displayInitial': 'M',
        'gender': 'male',
        'madhhab': 'hanafi',
        'countryCode': 'TR',
        'city': 'İstanbul',
        'timezone': 'Europe/Istanbul',
        'status': 'active',
        'createdAt': now,
        'updatedAt': now,
        'notificationPreferences': <String, bool>{},
        'onboardingCompleted': false,
      });
      snapshot = await reference.get();
    }
    if (revision != _revision) return;

    final data = snapshot.data() ?? const <String, dynamic>{};
    final preferences = await SharedPreferences.getInstance();
    final localComplete = preferences.getBool(_preferenceKey(user.uid));
    final displayName = (data['displayName'] as String? ?? '').trim();
    final complete =
        localComplete == true ||
        data['onboardingCompleted'] == true ||
        (displayName.isNotEmpty && displayName != 'Misafir');
    final suspended = data['status'] == 'suspended';
    if (complete && localComplete != true) {
      await preferences.setBool(_preferenceKey(user.uid), true);
    }

    _userId = user.uid;
    _onboardingComplete = complete;
    _accountSuspended = suspended;
    _initialized = true;
    notifyListeners();

    // Routing only needs the session decision above. Network-backed services
    // can become ready in the background instead of holding the launch screen.
    unawaited(
      _initializeUserServices(complete: complete, suspended: suspended),
    );
  }

  Future<void> _initializeUserServices({
    required bool complete,
    required bool suspended,
  }) async {
    if (complete && !suspended) {
      try {
        await PrayerScheduleSyncService.instance.sync();
      } catch (error) {
        debugPrint('Prayer schedule synchronization failed: $error');
      }
      try {
        await AlarmCoordinator.instance.initialize(onOpenGroup: _onOpenGroup);
      } catch (error) {
        debugPrint('Prayer alarm reconfiguration failed: $error');
      }
    }
    try {
      await PushNotificationService.instance.initialize(
        onOpenGroup: _onOpenGroup,
      );
    } catch (error) {
      debugPrint('Push notification reconfiguration failed: $error');
    }
    try {
      await OfflineActionQueue.instance.flush();
    } catch (error) {
      debugPrint('Offline action flush failed: $error');
    }
  }

  String _preferenceKey(String userId) => 'onboarding_completed_$userId';
}
