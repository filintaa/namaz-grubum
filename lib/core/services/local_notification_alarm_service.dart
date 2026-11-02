import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'alarm_service.dart';
import '../domain/models.dart';

class LocalNotificationAlarmService implements AlarmService {
  LocalNotificationAlarmService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const _channelId = 'prayer_alarms';
  static const _categoryId = 'prayer_alarm';
  static const _reminderCategoryId = 'prayer_reminder';
  static const _payloadPrefix = 'prayer:';

  Future<void> initialize({
    required String timezone,
    DidReceiveNotificationResponseCallback? onResponse,
    DidReceiveBackgroundNotificationResponseCallback? onBackgroundResponse,
  }) async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(timezone));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          _categoryId,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain('awake', 'Kalktım'),
            DarwinNotificationAction.plain('snooze', 'Ertele'),
          ],
        ),
        DarwinNotificationCategory(
          _reminderCategoryId,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain('snooze', 'Ertele'),
          ],
        ),
      ],
    );
    await _plugin.initialize(
      settings: InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: onResponse,
      onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
    );
    _initialized = true;
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'Alarm service must be initialized with an IANA timezone.',
      );
    }
  }

  @override
  Future<bool> requestPermission() async {
    _ensureInitialized();
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final notifications = await android?.requestNotificationsPermission();
      final exactAlarms = await android?.requestExactAlarmsPermission();
      return (notifications ?? false) && (exactAlarms ?? false);
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true, badge: false) ??
          false;
    }
    return false;
  }

  @override
  Future<void> replacePrayerAlarms(List<PrayerAlarm> alarms) async {
    _ensureInitialized();
    await cancelAllPrayerAlarms();
    final upcoming = selectUpcomingAlarms(alarms, now: DateTime.now());
    for (final alarm in upcoming) {
      await _plugin.zonedSchedule(
        id: alarm.id,
        title: alarm.title,
        body: alarm.body,
        scheduledDate: tz.TZDateTime.from(alarm.scheduledAt, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Namaz alarmları',
            channelDescription: 'Cihazda planlanan namaz vakti alarmları',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            actions: alarm.prayer == Prayer.fajr
                ? const <AndroidNotificationAction>[
                    AndroidNotificationAction('awake', 'Kalktım'),
                    AndroidNotificationAction('snooze', 'Ertele'),
                  ]
                : const <AndroidNotificationAction>[
                    AndroidNotificationAction('snooze', 'Ertele'),
                  ],
          ),
          iOS: DarwinNotificationDetails(
            presentSound: true,
            presentBanner: true,
            presentList: true,
            categoryIdentifier: alarm.prayer == Prayer.fajr
                ? _categoryId
                : _reminderCategoryId,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload:
            '$_payloadPrefix${alarm.prayer.name}:${alarm.dateKey ?? _dateKey(alarm.scheduledAt)}'
            '${alarm.endsAt == null ? '' : ':${alarm.endsAt!.millisecondsSinceEpoch}'}',
      );
    }
  }

  Future<void> snooze(
    Prayer prayer, {
    Duration delay = const Duration(minutes: 10),
    String? payload,
  }) async {
    _ensureInitialized();
    final scheduledAt = tz.TZDateTime.now(tz.local).add(delay);
    final parts = payload?.split(':') ?? const <String>[];
    final endsAtMillis = parts.length > 3 ? int.tryParse(parts[3]) : null;
    // Never turn an expired prayer reminder into a new out-of-window alarm.
    if (endsAtMillis == null ||
        !scheduledAt.isBefore(
          DateTime.fromMillisecondsSinceEpoch(endsAtMillis),
        )) {
      return;
    }
    await _plugin.zonedSchedule(
      id: 9000 + prayer.index,
      title: '${prayer.label} hatırlatması',
      body: 'Erteleme süresi doldu.',
      scheduledDate: scheduledAt,
      notificationDetails: NotificationDetails(
        android: const AndroidNotificationDetails(
          _channelId,
          'Namaz alarmları',
          channelDescription: 'Cihazda planlanan namaz vakti alarmları',
          importance: Importance.max,
          priority: Priority.max,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: prayer == Prayer.fajr
              ? _categoryId
              : _reminderCategoryId,
          presentSound: true,
          presentBanner: true,
          presentList: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      // Keep the original prayer date and deadline, including after midnight.
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> showGroupNotification({
    required int id,
    required String title,
    required String body,
    required String groupId,
  }) async {
    _ensureInitialized();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'group_reminders',
          'Grup hatırlatmaları',
          channelDescription: 'Grup üyelerinden gelen namaz hatırlatmaları',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
      payload: 'group:$groupId',
    );
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @visibleForTesting
  static List<PrayerAlarm> selectUpcomingAlarms(
    List<PrayerAlarm> alarms, {
    required DateTime now,
  }) {
    final upcoming =
        alarms
            .where(
              (alarm) =>
                  alarm.scheduledAt.isAfter(now) &&
                  (alarm.endsAt == null ||
                      alarm.scheduledAt.isBefore(alarm.endsAt!)),
            )
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    // Keep up to eight days of main prayer-time alarms even when near-term
    // follow-ups would otherwise fill iOS's queue. Reserve four extra slots.
    final primary = upcoming
        .where((alarm) => alarm.isPrimary)
        .take(40)
        .toList();
    final primaryIds = primary.map((alarm) => alarm.id).toSet();
    final selected = <PrayerAlarm>[
      ...primary,
      ...upcoming
          .where((alarm) => !primaryIds.contains(alarm.id))
          .take(60 - primary.length),
    ]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return selected;
  }

  Future<void> cancelPrayerAlarms(Prayer prayer, String dateKey) async {
    final prefix = '$_payloadPrefix${prayer.name}:$dateKey';
    for (final request in await _plugin.pendingNotificationRequests()) {
      if (request.payload == prefix ||
          (request.payload?.startsWith('$prefix:') ?? false)) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  @override
  Future<void> cancelAllPrayerAlarms() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.payload?.startsWith(_payloadPrefix) ?? false) {
        await _plugin.cancel(id: request.id);
      }
    }
  }
}
