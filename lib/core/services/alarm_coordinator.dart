import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../firebase_options.dart';
import '../domain/models.dart';
import 'alarm_service.dart';
import 'local_notification_alarm_service.dart';

@pragma('vm:entry-point')
Future<void> prayerAlarmBackgroundResponse(
  NotificationResponse response,
) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  if (response.actionId == 'snooze') {
    final parts = response.payload?.split(':') ?? const <String>[];
    final prayer = parts.length >= 2
        ? Prayer.values.where((item) => item.name == parts[1]).firstOrNull
        : null;
    if (prayer != null) {
      if (parts.length < 3 ||
          await AlarmCoordinator.shouldSkipPrayerReminder(prayer, parts[2])) {
        return;
      }
      var timezone = 'Europe/Istanbul';
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final profile = await FirebaseFirestore.instance
            .doc('users/$userId')
            .get();
        timezone = profile.data()?['timezone'] as String? ?? timezone;
      }
      final alarms = LocalNotificationAlarmService();
      await alarms.initialize(
        timezone: timezone,
        onBackgroundResponse: prayerAlarmBackgroundResponse,
      );
      await alarms.snooze(prayer, payload: response.payload);
    }
    return;
  }
  await AlarmCoordinator.handleResponse(response, background: true);
}

class AlarmCoordinator {
  AlarmCoordinator._();
  static final instance = AlarmCoordinator._();
  final LocalNotificationAlarmService _alarms = LocalNotificationAlarmService();
  void Function(String groupId)? _onOpenGroup;
  bool _initialized = false;
  Future<void> _notificationUpdates = Future<void>.value();

  Future<void> _updateNotifications(Future<void> Function() action) {
    final update = _notificationUpdates.then((_) => action());
    // A failed platform operation must not block later cancellations/retries.
    _notificationUpdates = update.catchError((Object error) {});
    return update;
  }

  Future<void> initialize({void Function(String groupId)? onOpenGroup}) async {
    _onOpenGroup = onOpenGroup;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    var timezone = 'Europe/Istanbul';
    final profile = await FirebaseFirestore.instance.doc('users/$userId').get();
    timezone = profile.data()?['timezone'] as String? ?? timezone;
    await _alarms.initialize(
      timezone: timezone,
      onResponse: (response) => unawaited(handleResponse(response)),
      onBackgroundResponse: prayerAlarmBackgroundResponse,
    );
    _initialized = true;
    await _scheduleAvailableDays();
  }

  Future<bool> requestPermissionAndSchedule() async {
    final granted = await _alarms.requestPermission();
    if (granted) await _scheduleAvailableDays();
    return granted;
  }

  Future<void> showForegroundGroupNotification({
    required String title,
    required String body,
    required String groupId,
  }) => _alarms.showGroupNotification(
    id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
    title: title,
    body: body,
    groupId: groupId,
  );

  Future<void> _scheduleAvailableDays() async {
    final now = tz.TZDateTime.now(tz.local);
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final profile = await FirebaseFirestore.instance.doc('users/$userId').get();
    final preferences = await SharedPreferences.getInstance();
    final enabled =
        profile.data()?['notificationPreferences']?['enabled'] != false;
    await preferences.setBool('prayer_notifications_enabled_$userId', enabled);
    if (!enabled) {
      await _updateNotifications(_alarms.cancelAllPrayerAlarms);
      return;
    }
    final alarms = <PrayerAlarm>[];
    for (final date in <DateTime>[
      for (var offset = -1; offset < 8; offset++)
        DateTime(now.year, now.month, now.day + offset),
    ]) {
      final key = _dateKey(date);
      final day = await FirebaseFirestore.instance
          .doc('users/$userId/prayerDays/$key')
          .get();
      final windows = day.data()?['windows'] as Map<String, dynamic>?;
      if (windows == null) continue;
      for (final prayer in Prayer.values) {
        if (preferences.getBool(_completedKey(userId, key, prayer)) == true) {
          continue;
        }
        final value = windows[prayer.name] as Map<String, dynamic>?;
        final startsAt = value?['startsAt'] as Timestamp?;
        final endsAt = value?['endsAt'] as Timestamp?;
        if (startsAt == null || endsAt == null) continue;
        alarms.addAll(
          buildPrayerAlarms(
            dateKey: key,
            prayer: prayer,
            startsAt: startsAt.toDate(),
            endsAt: endsAt.toDate(),
          ),
        );
      }
    }
    await _updateNotifications(() async {
      await preferences.reload();
      if (preferences.getBool('prayer_notifications_enabled_$userId') ==
          false) {
        await _alarms.cancelAllPrayerAlarms();
        return;
      }
      await _alarms.replacePrayerAlarms(
        alarms
            .where(
              (alarm) =>
                  preferences.getBool(
                    _completedKey(userId, alarm.dateKey!, alarm.prayer),
                  ) !=
                  true,
            )
            .toList(),
      );
    });
  }

  Future<void> markPrayerCompleted({
    required Prayer prayer,
    required String dateKey,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_completedKey(userId, dateKey, prayer), true);
    await _updateNotifications(
      () => _alarms.cancelPrayerAlarms(prayer, dateKey),
    );
  }

  Future<void> setLocalNotificationsEnabled(bool enabled) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(
        'prayer_notifications_enabled_$userId',
        enabled,
      );
    }
    if (!enabled) {
      await _updateNotifications(_alarms.cancelAllPrayerAlarms);
    } else {
      if (!_initialized) await initialize(onOpenGroup: _onOpenGroup);
      await requestPermissionAndSchedule();
    }
  }

  static String _completedKey(String userId, String dateKey, Prayer prayer) =>
      'prayer_completed_${userId}_${dateKey}_${prayer.name}';

  static Future<bool> shouldSkipPrayerReminder(
    Prayer prayer,
    String dateKey,
  ) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return true;
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    return preferences.getBool('prayer_notifications_enabled_$userId') ==
            false ||
        preferences.getBool(_completedKey(userId, dateKey, prayer)) == true;
  }

  /// Plans an escalating but bounded reminder sequence for a prayer window.
  ///
  /// Every reminder is kept inside its real prayer window. The notification
  /// service discards times that have already passed when it schedules them.
  @visibleForTesting
  static List<PrayerAlarm> buildPrayerAlarms({
    required String dateKey,
    required Prayer prayer,
    required DateTime startsAt,
    required DateTime endsAt,
  }) {
    final baseId =
        int.parse(dateKey.replaceAll('-', '')) * 100 + prayer.index * 10;
    if (!endsAt.isAfter(startsAt)) return const <PrayerAlarm>[];
    final times = <DateTime>[
      startsAt.subtract(const Duration(minutes: 10)),
      startsAt,
      startsAt.add(const Duration(minutes: 5)),
      startsAt.add(Duration(minutes: prayer == Prayer.fajr ? 10 : 15)),
      startsAt.add(Duration(minutes: prayer == Prayer.fajr ? 20 : 30)),
      endsAt.subtract(const Duration(minutes: 10)),
    ];
    final seen = <DateTime>{};
    final alarms = <PrayerAlarm>[];
    for (var index = 0; index < times.length; index++) {
      final time = times[index];
      if (!time.isBefore(endsAt) ||
          (index == 5 && !time.isAfter(startsAt)) ||
          !seen.add(time)) {
        continue;
      }
      alarms.add(
        PrayerAlarm(
          id: baseId + index,
          prayer: prayer,
          scheduledAt: time,
          dateKey: dateKey,
          endsAt: endsAt,
          isPrimary: index == 1,
          title: index == 0
              ? '${prayer.label} yaklaşıyor'
              : index == 1
              ? '${prayer.label} vakti'
              : index == 5
              ? '${prayer.label} vakti bitmek üzere'
              : '${prayer.label} hatırlatması',
          body: index == 0
              ? '10 dakika sonra ${prayer.label} vakti başlayacak. Hazırlan.'
              : index == 5
              ? 'Vaktin bitmesine 10 dakika kaldı. Namazını tamamla.'
              : prayer == Prayer.fajr
              ? 'Sabah namazı için kalk. Kıldığında uygulamada işaretle.'
              : '${prayer.label} vakti devam ediyor. Kıldığında uygulamada işaretle.',
        ),
      );
    }
    alarms.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return alarms;
  }

  static Future<void> handleResponse(
    NotificationResponse response, {
    bool background = false,
  }) async {
    final payload = response.payload;
    if (payload == null) return;
    if (payload.startsWith('group:')) {
      final groupId = payload.substring('group:'.length);
      if (groupId.isNotEmpty) instance._onOpenGroup?.call(groupId);
      return;
    }
    if (!payload.startsWith('prayer:')) return;
    final parts = payload.split(':');
    if (parts.length < 3) return;
    final prayer = Prayer.values
        .where((item) => item.name == parts[1])
        .firstOrNull;
    if (prayer == null) return;
    if (response.actionId == 'snooze') {
      if (await shouldSkipPrayerReminder(prayer, parts[2])) return;
      if (!background) await instance._alarms.snooze(prayer, payload: payload);
      return;
    }
    if (response.actionId == 'awake' && prayer == Prayer.fajr) {
      try {
        await FirebaseFunctions.instanceFor(
          region: 'europe-west1',
        ).httpsCallable('recordAlarmAction').call(<String, Object>{
          'prayer': prayer.name,
          'dateKey': parts[2],
          'action': 'awake',
        });
      } catch (error) {
        debugPrint('Alarm action failed: $error');
      }
    }
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
