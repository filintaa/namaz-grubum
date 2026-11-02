import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TelemetryService {
  TelemetryService._();

  static final instance = TelemetryService._();
  static const _preferenceKey = 'diagnostics_consent';

  bool _enabled = false;
  bool get enabled => _enabled;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _enabled = preferences.getBool(_preferenceKey) ?? false;
    await _apply();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_preferenceKey, value);
    await _apply();
  }

  Future<void> track(String event, {Map<String, Object>? parameters}) async {
    if (!_enabled) return;
    await FirebaseAnalytics.instance.logEvent(
      name: event,
      parameters: parameters,
    );
  }

  Future<void> _apply() async {
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(_enabled);
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      _enabled,
    );
  }
}
