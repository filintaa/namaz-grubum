import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class PrayerScheduleSyncException implements Exception {
  const PrayerScheduleSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PrayerScheduleSyncService {
  PrayerScheduleSyncService._();

  static final instance = PrayerScheduleSyncService._();
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  static const _cityCoordinates = <String, (double, double)>{
    'istanbul': (41.0082, 28.9784),
    'ankara': (39.9334, 32.8597),
    'izmir': (38.4237, 27.1428),
    'bursa': (40.1950, 29.0600),
    'antalya': (36.8969, 30.7133),
    'konya': (37.8746, 32.4932),
    'adana': (36.9914, 35.3308),
    'gaziantep': (37.0662, 37.3833),
    'diyarbakir': (37.9144, 40.2306),
    'trabzon': (41.0015, 39.7178),
  };

  Future<bool> sync({
    bool requestLocation = false,
    String? fallbackCity,
    bool force = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final profile = await FirebaseFirestore.instance
        .doc('users/${user.uid}')
        .get();
    final data = profile.data() ?? const <String, dynamic>{};
    Position? position;
    var permission = await Geolocator.checkPermission();
    if (requestLocation && permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    final locationEnabled = requestLocation || data['locationEnabled'] == true;
    if (locationEnabled &&
        (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse)) {
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        position = null;
      }
    }

    final stored = data['prayerCoordinates'] as GeoPoint?;
    final updatedAt = data['prayerScheduleUpdatedAt'] as Timestamp?;
    final cityName = fallbackCity ?? data['city'] as String? ?? 'İstanbul';
    final city = _normalizeCity(cityName);
    final storedSource = data['prayerLocationSource'] as String?;
    final storedCity = data['prayerLocationCity'] as String?;
    final hasKnownStoredSource =
        storedSource == 'device' || storedSource == 'city';
    final cityChanged =
        storedSource == 'city' &&
        storedCity != null &&
        _normalizeCity(storedCity) != city;
    final legacyLocation = stored != null && !hasKnownStoredSource;
    final fresh =
        updatedAt != null &&
        DateTime.now().difference(updatedAt.toDate()) <
            const Duration(hours: 6);
    final moved =
        position != null &&
        stored != null &&
        Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              stored.latitude,
              stored.longitude,
            ) >=
            10000;
    if (!force && fresh && !moved && !cityChanged && !legacyLocation) {
      return true;
    }

    final useStored =
        position == null &&
        stored != null &&
        !cityChanged &&
        !legacyLocation &&
        fallbackCity == null;
    final cityCoordinates = position == null && !useStored
        ? await _coordinatesForCity(cityName)
        : null;
    final latitude =
        position?.latitude ??
        stored?.latitudeIf(useStored) ??
        cityCoordinates!.$1;
    final longitude =
        position?.longitude ??
        stored?.longitudeIf(useStored) ??
        cityCoordinates!.$2;
    final locationSource = position != null
        ? 'device'
        : useStored
        ? storedSource!
        : 'city';
    await _functions.httpsCallable('syncPrayerSchedule').call(<String, Object>{
      'latitude': latitude,
      'longitude': longitude,
      'locationSource': locationSource,
      if (locationSource == 'city')
        'locationCity': useStored ? storedCity! : cityName.trim(),
      'locationEnabled':
          locationEnabled &&
          (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse),
    });
    return true;
  }

  Future<(double, double)> _coordinatesForCity(String cityName) async {
    final normalized = _normalizeCity(cityName);
    final known = _cityCoordinates[normalized];
    if (known != null) return known;
    if (normalized.isEmpty) {
      throw const PrayerScheduleSyncException(
        'Namaz vakitleri için şehir yaz veya konum iznini aç.',
      );
    }

    try {
      final results = await locationFromAddress(
        cityName.trim(),
      ).timeout(const Duration(seconds: 8));
      if (results.isNotEmpty) {
        return (results.first.latitude, results.first.longitude);
      }
    } catch (_) {
      // The user-facing error below covers timeout, connectivity and bad data.
    }
    throw PrayerScheduleSyncException(
      '“${cityName.trim()}” şehri bulunamadı. Şehir adını kontrol et veya konum iznini aç.',
    );
  }

  String _normalizeCity(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');
}

extension on GeoPoint {
  double? latitudeIf(bool condition) => condition ? latitude : null;
  double? longitudeIf(bool condition) => condition ? longitude : null;
}
