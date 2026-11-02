import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_repository.dart';
import 'demo_repository.dart';
import 'firebase_app_repository.dart';
import '../services/firebase_photo_service.dart';
import '../services/group_logo_service.dart';
import '../services/photo_service.dart';

final appRepositoryProvider = Provider<AppRepository>((ref) {
  if (Firebase.apps.isNotEmpty) return FirebaseAppRepository();
  return DemoAppRepository();
});

final photoServiceProvider = Provider<PhotoService>((ref) {
  if (Firebase.apps.isEmpty) {
    throw StateError('Fotoğraf servisi için Firebase bağlantısı gerekli.');
  }
  return FirebasePhotoService();
});

final groupLogoServiceProvider = Provider<GroupLogoService>((ref) {
  if (Firebase.apps.isEmpty) {
    throw StateError('Logo servisi için Firebase bağlantısı gerekli.');
  }
  return GroupLogoService();
});
