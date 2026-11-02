import '../domain/models.dart';

class PrayerAlarm {
  const PrayerAlarm({
    required this.id,
    required this.prayer,
    required this.scheduledAt,
    required this.title,
    required this.body,
    this.dateKey,
    this.endsAt,
    this.isPrimary = false,
  });

  final int id;
  final Prayer prayer;
  final DateTime scheduledAt;
  final String title;
  final String body;
  final String? dateKey;
  final DateTime? endsAt;
  final bool isPrimary;
}

abstract interface class AlarmService {
  Future<bool> requestPermission();
  Future<void> replacePrayerAlarms(List<PrayerAlarm> alarms);
  Future<void> cancelAllPrayerAlarms();
}
