import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:namaz_grubum/core/domain/models.dart';
import 'package:namaz_grubum/core/services/alarm_service.dart';
import 'package:namaz_grubum/core/services/local_notification_alarm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  late List<MethodCall> calls;
  late List<Map<String, Object?>> pending;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    calls = [];
    pending = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'pendingNotificationRequests') return pending;
          if (call.method == 'initialize') return true;
          return null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'completion cancels only the selected prayer/date including snooze',
    () async {
      pending = [
        {'id': 1, 'payload': 'prayer:fajr:2026-09-14:123'},
        {'id': 9000, 'payload': 'prayer:fajr:2026-09-14:123'},
        {'id': 2, 'payload': 'prayer:isha:2026-09-14:123'},
        {'id': 3, 'payload': 'prayer:fajr:2026-09-15:123'},
        {'id': 4, 'payload': 'group:example'},
      ];
      await LocalNotificationAlarmService().cancelPrayerAlarms(
        Prayer.fajr,
        '2026-09-14',
      );
      expect(
        calls
            .where((call) => call.method == 'cancel')
            .map((call) => call.arguments),
        [1, 9000],
      );
    },
  );

  test(
    'turning off prayer alarms does not cancel unrelated group notifications',
    () async {
      pending = [
        {'id': 1, 'payload': 'prayer:fajr:2026-09-14:123'},
        {'id': 2, 'payload': 'group:example'},
      ];
      await LocalNotificationAlarmService().cancelAllPrayerAlarms();
      expect(
        calls
            .where((call) => call.method == 'cancel')
            .map((call) => call.arguments),
        [1],
      );
    },
  );

  test('snooze is rejected when it would pass the prayer deadline', () async {
    final service = LocalNotificationAlarmService();
    await service.initialize(timezone: 'Europe/Istanbul');
    final deadline = DateTime.now()
        .add(const Duration(minutes: 5))
        .millisecondsSinceEpoch;
    await service.snooze(
      Prayer.fajr,
      payload: 'prayer:fajr:2026-09-14:$deadline',
    );
    expect(calls.where((call) => call.method == 'zonedSchedule'), isEmpty);
  });

  test(
    'valid snooze keeps the original prayer date/deadline and sound',
    () async {
      final service = LocalNotificationAlarmService();
      await service.initialize(timezone: 'Europe/Istanbul');
      final deadline = DateTime.now()
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch;
      final payload = 'prayer:isha:2026-09-14:$deadline';
      await service.snooze(Prayer.isha, payload: payload);
      final arguments =
          calls.singleWhere((call) => call.method == 'zonedSchedule').arguments
              as Map;
      expect(arguments['payload'], payload);
      expect((arguments['platformSpecifics'] as Map)['presentSound'], true);
      expect(
        (arguments['platformSpecifics'] as Map)['categoryIdentifier'],
        'prayer_reminder',
      );
    },
  );

  test(
    'scheduled payload preserves original isha date and enables iOS sound',
    () async {
      final service = LocalNotificationAlarmService();
      await service.initialize(timezone: 'Europe/Istanbul');
      final time = DateTime.now().add(const Duration(hours: 1));
      final deadline = time.add(const Duration(hours: 1));
      await service.replacePrayerAlarms([
        PrayerAlarm(
          id: 7,
          prayer: Prayer.isha,
          scheduledAt: time,
          title: 'Yatsı',
          body: 'Hatırlatma',
          dateKey: '2026-09-14',
          endsAt: deadline,
        ),
      ]);
      final arguments =
          calls.singleWhere((call) => call.method == 'zonedSchedule').arguments
              as Map;
      expect(
        arguments['payload'],
        'prayer:isha:2026-09-14:${deadline.millisecondsSinceEpoch}',
      );
      expect((arguments['platformSpecifics'] as Map)['presentSound'], true);
    },
  );
}
