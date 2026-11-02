import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_grubum/core/domain/models.dart';
import 'package:namaz_grubum/core/services/alarm_coordinator.dart';
import 'package:namaz_grubum/core/services/alarm_service.dart';
import 'package:namaz_grubum/core/services/local_notification_alarm_service.dart';

void main() {
  group('prayer alarm planning', () {
    test('creates an escalating sequence with stable, distinct IDs', () {
      final startsAt = DateTime(2026, 9, 10, 5, 30);
      final alarms = AlarmCoordinator.buildPrayerAlarms(
        dateKey: '2026-09-10',
        prayer: Prayer.fajr,
        startsAt: startsAt,
        endsAt: DateTime(2026, 9, 10, 7),
      );

      expect(alarms, hasLength(6));
      expect(alarms.map((alarm) => alarm.scheduledAt), <DateTime>[
        DateTime(2026, 9, 10, 5, 20),
        startsAt,
        DateTime(2026, 9, 10, 5, 35),
        DateTime(2026, 9, 10, 5, 40),
        DateTime(2026, 9, 10, 5, 50),
        DateTime(2026, 9, 10, 6, 50),
      ]);
      expect(alarms.map((alarm) => alarm.id).toSet(), hasLength(6));
      expect(alarms[0].title, 'Sabah yaklaşıyor');
      expect(alarms[1].title, 'Sabah vakti');
    });

    test('does not schedule reminders after the prayer window ends', () {
      final alarms = AlarmCoordinator.buildPrayerAlarms(
        dateKey: '2026-09-10',
        prayer: Prayer.maghrib,
        startsAt: DateTime(2026, 9, 10, 19),
        endsAt: DateTime(2026, 9, 10, 19, 20),
      );

      expect(alarms, hasLength(5));
      expect(
        alarms.every(
          (alarm) => !alarm.scheduledAt.isAfter(DateTime(2026, 9, 10, 19, 20)),
        ),
        isTrue,
      );
    });
  });

  test('deduplicates deadlines and excludes the exact end boundary', () {
    final alarms = AlarmCoordinator.buildPrayerAlarms(
      dateKey: '2026-09-10',
      prayer: Prayer.maghrib,
      startsAt: DateTime(2026, 9, 10, 19),
      endsAt: DateTime(2026, 9, 10, 19, 15),
    );
    expect(alarms.map((alarm) => alarm.scheduledAt).toSet(), hasLength(3));
    expect(
      alarms.every((alarm) => alarm.scheduledAt.isBefore(alarm.endsAt!)),
      isTrue,
    );
  });

  test('preserves original prayer date for an overnight isha deadline', () {
    final alarms = AlarmCoordinator.buildPrayerAlarms(
      dateKey: '2026-09-10',
      prayer: Prayer.isha,
      startsAt: DateTime(2026, 9, 10, 20),
      endsAt: DateTime(2026, 9, 11, 5),
    );
    expect(alarms.last.scheduledAt, DateTime(2026, 9, 11, 4, 50));
    expect(alarms.every((alarm) => alarm.dateKey == '2026-09-10'), isTrue);
  });

  test('invalid prayer window creates no notifications', () {
    expect(
      AlarmCoordinator.buildPrayerAlarms(
        dateKey: '2026-09-10',
        prayer: Prayer.fajr,
        startsAt: DateTime(2026, 9, 10, 7),
        endsAt: DateTime(2026, 9, 10, 5),
      ),
      isEmpty,
    );
  });

  test('keeps the nearest 60 future alarms chronologically', () {
    final now = DateTime(2026, 9, 10, 5);
    final alarms = List.generate(
      80,
      (index) => PrayerAlarm(
        id: index,
        prayer: Prayer.fajr,
        scheduledAt: now.add(Duration(minutes: index - 1)),
        title: 'Test',
        body: 'Test',
      ),
    ).reversed.toList();
    final selected = LocalNotificationAlarmService.selectUpcomingAlarms(
      alarms,
      now: now,
    );
    expect(selected, hasLength(60));
    expect(selected.first.scheduledAt, now.add(const Duration(minutes: 1)));
    expect(selected.last.scheduledAt, now.add(const Duration(minutes: 60)));
  });

  test(
    'preserves distant primary prayer alarms despite crowded follow-ups',
    () {
      final now = DateTime(2026, 9, 10, 5);
      final alarms = <PrayerAlarm>[
        for (var index = 0; index < 80; index++)
          PrayerAlarm(
            id: index,
            prayer: Prayer.fajr,
            scheduledAt: now.add(Duration(minutes: index + 1)),
            title: 'Test',
            body: 'Test',
          ),
        PrayerAlarm(
          id: 100,
          prayer: Prayer.fajr,
          isPrimary: true,
          scheduledAt: now.add(const Duration(days: 7)),
          title: 'Ana alarm',
          body: 'Test',
        ),
      ];
      final selected = LocalNotificationAlarmService.selectUpcomingAlarms(
        alarms,
        now: now,
      );
      expect(selected, hasLength(60));
      expect(selected.last.id, 100);
    },
  );
}
