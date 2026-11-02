import 'dart:convert';
import 'dart:isolate';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

import 'photo_service.dart';
import 'alarm_coordinator.dart';
import '../domain/models.dart';

class FirebasePhotoService implements PhotoService {
  FirebasePhotoService({
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  Future<String> _dateKeyFor(String userId, String prayer) async {
    final profile = await FirebaseFirestore.instance.doc('users/$userId').get();
    final timezoneName =
        profile.data()?['timezone'] as String? ?? 'Europe/Istanbul';
    tz_data.initializeTimeZones();
    final location = tz.getLocation(timezoneName);
    final now = tz.TZDateTime.now(location);
    String key(DateTime date) =>
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    if (prayer == 'isha') {
      final previousKey = key(now.subtract(const Duration(days: 1)));
      final previous = await FirebaseFirestore.instance
          .doc('users/$userId/prayerDays/$previousKey')
          .get();
      final window =
          (previous.data()?['windows'] as Map<String, dynamic>?)?['isha']
              as Map<String, dynamic>?;
      final startsAt = window?['startsAt'] as Timestamp?;
      final endsAt = window?['endsAt'] as Timestamp?;
      if (startsAt != null &&
          endsAt != null &&
          !DateTime.now().isBefore(startsAt.toDate()) &&
          DateTime.now().isBefore(endsAt.toDate())) {
        return previousKey;
      }
    }
    return key(now);
  }

  @override
  Future<PhotoUploadReceipt> uploadCameraPhoto({
    required Uint8List jpegBytes,
    required String groupId,
    required String prayer,
    required String idempotencyKey,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const PhotoUploadException(
        'Oturumun kapanmış. Lütfen yeniden giriş yap.',
      );
    }

    final preparedBytes = await Isolate.run(
      () => preparePhotoForUpload(jpegBytes),
    );

    late final String dateKey;
    try {
      dateKey = await _dateKeyFor(user.uid, prayer);
    } on FirebaseException catch (error) {
      throw PhotoUploadException(_messageForFirebaseError(error), cause: error);
    }
    final fileId = sha256.convert(utf8.encode(idempotencyKey)).toString();
    final objectKey = 'prayer-photos/$groupId/$dateKey/${user.uid}/$fileId.jpg';
    final reference = _storage.ref(objectKey);

    try {
      await reference.putData(
        preparedBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'private,max-age=3600',
          customMetadata: const {'source': 'camera'},
        ),
      );
      final response = await _functions
          .httpsCallable('registerPrayerPhoto')
          .call(<String, Object?>{
            'groupId': groupId,
            'prayer': prayer,
            'dateKey': dateKey,
            'objectKey': objectKey,
            'idempotencyKey': idempotencyKey,
          });
      final data = Map<String, dynamic>.from(response.data as Map);
      final completedPrayer = Prayer.values
          .where((value) => value.name == prayer)
          .firstOrNull;
      if (completedPrayer != null) {
        try {
          await AlarmCoordinator.instance.markPrayerCompleted(
            prayer: completedPrayer,
            dateKey: dateKey,
          );
        } catch (error) {
          debugPrint('Photo prayer alarm cancellation failed: $error');
        }
      }
      return PhotoUploadReceipt(
        photoId: data['photoId'] as String,
        objectKey: objectKey,
        expiresAt: DateTime.parse(data['expiresAt'] as String),
      );
    } on FirebaseFunctionsException catch (error) {
      await reference.delete().catchError((_) {});
      throw PhotoUploadException(
        _messageForFunctionsError(error),
        cause: error,
      );
    } on FirebaseException catch (error) {
      throw PhotoUploadException(_messageForFirebaseError(error), cause: error);
    } on PhotoUploadException {
      rethrow;
    } catch (error) {
      throw PhotoUploadException(
        'Fotoğraf gönderilemedi. Lütfen tekrar dene.',
        cause: error,
      );
    }
  }

  String _messageForFunctionsError(FirebaseFunctionsException error) {
    final serverMessage = error.message?.trim();
    if (serverMessage != null && serverMessage.isNotEmpty) return serverMessage;
    return switch (error.code) {
      'unauthenticated' => 'Oturumun kapanmış. Lütfen yeniden giriş yap.',
      'permission-denied' => 'Bu gruba fotoğraf gönderme yetkin yok.',
      'failed-precondition' =>
        'Fotoğraf yalnızca seçili namazın vakti içinde gönderilebilir.',
      'unavailable' || 'deadline-exceeded' =>
        'Sunucuya ulaşılamadı. Bağlantını kontrol edip tekrar dene.',
      _ => 'Fotoğraf kaydedilemedi. Lütfen tekrar dene.',
    };
  }

  String _messageForFirebaseError(FirebaseException error) =>
      switch (error.code) {
        'unauthenticated' => 'Oturumun kapanmış. Lütfen yeniden giriş yap.',
        'unauthorized' ||
        'permission-denied' => 'Bu gruba fotoğraf gönderme yetkin yok.',
        'canceled' => 'Fotoğraf gönderimi iptal edildi.',
        'retry-limit-exceeded' || 'unavailable' || 'network-request-failed' =>
          'Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.',
        'quota-exceeded' => 'Fotoğraf depolama kotası doldu.',
        _ => 'Fotoğraf yüklenemedi (${error.code}). Lütfen tekrar dene.',
      };
}
