import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_coordinator.dart';
import 'demo_session_controller.dart';
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
  bool _replacingInvalidUser = false;

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
      await DemoSessionController.instance.initialize();
      _onboardingComplete = DemoSessionController.instance.onboardingComplete;
      _initialized = true;
      notifyListeners();
      return;
    }

    await _authSubscription?.cancel();
    await refreshForCurrentUser();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (_replacingInvalidUser) return;
      if (_initialized && user?.uid == _userId) return;
      unawaited(_configureUser(user));
    });
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
      await DemoSessionController.instance.initialize();
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
    if (Firebase.apps.isEmpty) {
      await DemoSessionController.instance.clear();
      _onboardingComplete = false;
      notifyListeners();
      return;
    }
    final userId = forUserId ?? _userId;
    if (userId != null) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_preferenceKey(userId));
    }
    _onboardingComplete = false;
    notifyListeners();
  }

  Future<void> restartOnboarding() async {
    if (Firebase.apps.isEmpty) {
      await clearCompletion();
      return;
    }
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

    final preferences = await SharedPreferences.getInstance();
    var user = initialUser ?? (Firebase.apps.isNotEmpty ? FirebaseAuth.instance.currentUser : null);

    // Fast path: if the user was already authenticated in a previous launch,
    // use cached onboarding state so the UI becomes interactive immediately.
    if (user != null) {
      final cachedComplete = preferences.getBool(_preferenceKey(user.uid));
      if (cachedComplete != null && !_initialized) {
        _userId = user.uid;
        _onboardingComplete = cachedComplete;
        _initialized = true;
        notifyListeners();
      }
    }

    if (user == null && Firebase.apps.isNotEmpty) {
      user = (await FirebaseAuth.instance.signInAnonymously()).user;
    }
    if (user == null || revision != _revision) return;

    try {
      // Validate credential without forcing an expensive network round-trip.
      await user.getIdToken();
    } on FirebaseAuthException catch (error) {
      if (_isInvalidUserCredential(error.code)) {
        user = await _replaceInvalidUser();
        if (user == null || revision != _revision) return;
      } else {
        rethrow;
      }
    }

    final reference = FirebaseFirestore.instance.doc('users/${user.uid}');
    var snapshot = await _readUserProfile(reference, user);
    final profileExisted = snapshot.exists;
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
    final localComplete = preferences.getBool(_preferenceKey(user.uid));
    final displayName = (data['displayName'] as String? ?? '').trim();
    final complete =
        (profileExisted && localComplete == true) ||
        data['onboardingCompleted'] == true ||
        (displayName.isNotEmpty && displayName != 'Misafir');
    final suspended = data['status'] == 'suspended';
    if (complete && localComplete != true) {
      await preferences.setBool(_preferenceKey(user.uid), true);
    }

    final stateChanged = _userId != user.uid ||
        _onboardingComplete != complete ||
        _accountSuspended != suspended ||
        !_initialized;

    _userId = user.uid;
    _onboardingComplete = complete;
    _accountSuspended = suspended;
    _initialized = true;
    if (stateChanged) {
      notifyListeners();
    }

    // Routing only needs the session decision above. Network-backed services
    // can become ready in the background instead of holding the launch screen.
    unawaited(
      _initializeUserServices(complete: complete, suspended: suspended),
    );
  }

  Future<void> _refreshClientCredentials(User user) async {
    try {
      await user.getIdToken(true);
    } catch (error) {
      debugPrint('ID token refresh failed during session setup: $error');
    }
    try {
      await FirebaseAppCheck.instance.getToken(true);
    } catch (error) {
      // A temporary App Check refresh problem should not prevent an existing
      // authenticated user from reaching the profile read/retry below.
      debugPrint('App Check token refresh failed during session setup: $error');
    }
  }

  bool _isInvalidUserCredential(String code) => const <String>{
    'invalid-user-token',
    'user-disabled',
    'user-not-found',
    'user-token-expired',
  }.contains(code);

  Future<User?> _replaceInvalidUser() async {
    _replacingInvalidUser = true;
    try {
      await FirebaseAuth.instance.signOut();
      return (await FirebaseAuth.instance.signInAnonymously()).user;
    } finally {
      _replacingInvalidUser = false;
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _readUserProfile(
    DocumentReference<Map<String, dynamic>> reference,
    User user,
  ) async {
    try {
      return await reference.get();
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
      // A clean install can briefly observe auth before both the ID token and
      // App Check token are accepted by Firestore. Refresh once and retry;
      // persistent rule failures still surface on the second read.
      await _refreshClientCredentials(user);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return reference.get(const GetOptions(source: Source.server));
    }
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
