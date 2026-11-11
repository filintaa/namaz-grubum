import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

/// Keeps the Firebase-free demo experience internally consistent and makes
/// onboarding choices survive a simulator relaunch.
class DemoSessionController extends ChangeNotifier {
  DemoSessionController._();

  static final instance = DemoSessionController._();

  static const _completeKey = 'demo_onboarding_complete';
  static const _nameKey = 'demo_display_name';
  static const _cityKey = 'demo_city';
  static const _madhhabKey = 'demo_madhhab';
  static const _notificationsKey = 'demo_notifications_enabled';

  bool _initialized = false;
  bool _onboardingComplete = false;
  String _displayName = 'Muhammet A.';
  String _city = 'İstanbul';
  Madhhab _madhhab = Madhhab.hanafi;
  bool _notificationsEnabled = true;

  bool get onboardingComplete => _onboardingComplete;
  String get displayName => _displayName;
  String get city => _city;
  Madhhab get madhhab => _madhhab;
  bool get notificationsEnabled => _notificationsEnabled;

  Future<void> initialize() async {
    if (_initialized) return;
    final preferences = await SharedPreferences.getInstance();
    _onboardingComplete = preferences.getBool(_completeKey) ?? false;
    _displayName = preferences.getString(_nameKey) ?? _displayName;
    _city = preferences.getString(_cityKey) ?? _city;
    _madhhab = preferences.getString(_madhhabKey) == Madhhab.shafii.name
        ? Madhhab.shafii
        : Madhhab.hanafi;
    _notificationsEnabled =
        preferences.getBool(_notificationsKey) ?? _notificationsEnabled;
    _initialized = true;
  }

  Future<void> completeOnboarding({
    required String displayName,
    required String city,
    required Madhhab madhhab,
    required bool notificationsEnabled,
  }) async {
    _displayName = displayName.trim();
    _city = city.trim().isEmpty ? 'İstanbul' : city.trim();
    _madhhab = madhhab;
    _notificationsEnabled = notificationsEnabled;
    _onboardingComplete = true;
    _initialized = true;

    final preferences = await SharedPreferences.getInstance();
    await Future.wait(<Future<bool>>[
      preferences.setBool(_completeKey, true),
      preferences.setString(_nameKey, _displayName),
      preferences.setString(_cityKey, _city),
      preferences.setString(_madhhabKey, _madhhab.name),
      preferences.setBool(_notificationsKey, _notificationsEnabled),
    ]);
    notifyListeners();
  }

  Future<void> updateProfile({
    required String name,
    required String city,
  }) async {
    _displayName = name.trim();
    _city = city.trim().isEmpty ? _city : city.trim();
    final preferences = await SharedPreferences.getInstance();
    await Future.wait(<Future<bool>>[
      preferences.setString(_nameKey, _displayName),
      preferences.setString(_cityKey, _city),
    ]);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_notificationsKey, value);
    notifyListeners();
  }

  Future<void> clear() async {
    _initialized = true;
    _onboardingComplete = false;
    _displayName = 'Muhammet A.';
    _city = 'İstanbul';
    _madhhab = Madhhab.hanafi;
    _notificationsEnabled = true;
    final preferences = await SharedPreferences.getInstance();
    await Future.wait(<Future<bool>>[
      preferences.remove(_completeKey),
      preferences.remove(_nameKey),
      preferences.remove(_cityKey),
      preferences.remove(_madhhabKey),
      preferences.remove(_notificationsKey),
    ]);
    notifyListeners();
  }
}
