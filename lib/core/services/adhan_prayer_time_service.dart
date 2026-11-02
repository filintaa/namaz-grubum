import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/models.dart';
import 'prayer_time_service.dart';

class AdhanPrayerTimeService implements PrayerTimeService {
  AdhanPrayerTimeService() {
    tz_data.initializeTimeZones();
  }

  @override
  Future<PrayerSchedule> scheduleFor({
    required DateTime date,
    required double latitude,
    required double longitude,
    required Madhhab madhhab,
    required String timezone,
  }) async {
    final location = _locationFor(timezone);
    final localDate = tz.TZDateTime(
      location,
      date.year,
      date.month,
      date.day,
      12,
    );
    // The official Diyanet timetable uses the earlier Asr boundary. Applying
    // the Hanafi shadow ratio on top of the Turkey preset makes Asr roughly
    // 50 minutes later than Diyanet, so Turkey schedules always use this
    // boundary. The saved madhhab remains a user profile preference.
    final parameters = adhan.CalculationMethodParameters.turkiye()
      ..madhab = adhan.Madhab.shafi;
    final times = adhan.PrayerTimes(
      coordinates: adhan.Coordinates(latitude, longitude),
      date: localDate,
      calculationParameters: parameters,
      precision: true,
    );
    final nextDay = adhan.PrayerTimes(
      coordinates: adhan.Coordinates(latitude, longitude),
      date: localDate.add(const Duration(days: 1)),
      calculationParameters: parameters,
      precision: true,
    );
    DateTime local(DateTime value) => tz.TZDateTime.from(value, location);
    return PrayerSchedule(
      windows: <PrayerWindow>[
        PrayerWindow(
          prayer: Prayer.fajr,
          startsAt: local(times.fajr),
          endsAt: local(times.sunrise),
        ),
        PrayerWindow(
          prayer: Prayer.dhuhr,
          startsAt: local(times.dhuhr),
          endsAt: local(times.asr),
        ),
        PrayerWindow(
          prayer: Prayer.asr,
          startsAt: local(times.asr),
          endsAt: local(times.maghrib),
        ),
        PrayerWindow(
          prayer: Prayer.maghrib,
          startsAt: local(times.maghrib),
          endsAt: local(times.isha),
        ),
        PrayerWindow(
          prayer: Prayer.isha,
          startsAt: local(times.isha),
          endsAt: local(nextDay.fajr),
        ),
      ],
    );
  }

  tz.Location _locationFor(String name) => tz.getLocation(name);
}
