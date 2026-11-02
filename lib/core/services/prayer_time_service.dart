import '../domain/models.dart';

class PrayerSchedule {
  PrayerSchedule({required List<PrayerWindow> windows})
    : windows = List<PrayerWindow>.unmodifiable(windows) {
    if (windows.length != Prayer.values.length) {
      throw ArgumentError('A daily schedule must contain all five prayers.');
    }
    for (var index = 1; index < windows.length; index++) {
      if (!windows[index].startsAt.isAfter(windows[index - 1].startsAt)) {
        throw ArgumentError('Prayer windows must be chronological.');
      }
    }
  }

  final List<PrayerWindow> windows;

  PrayerWindow? get current {
    for (final window in windows) {
      if (window.isOpen) return window;
    }
    return null;
  }

  PrayerWindow get next {
    final now = DateTime.now();
    return windows.firstWhere(
      (window) => window.startsAt.isAfter(now),
      orElse: () => windows.first,
    );
  }
}

abstract interface class PrayerTimeService {
  /// Returns local-time prayer boundaries for the requested civil date.
  /// Implementations must persist source timestamps as UTC.
  Future<PrayerSchedule> scheduleFor({
    required DateTime date,
    required double latitude,
    required double longitude,
    required Madhhab madhhab,
    required String timezone,
  });
}
