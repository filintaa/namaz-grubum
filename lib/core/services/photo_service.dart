import 'dart:typed_data';

import 'package:image/image.dart' as image;

const int maximumPhotoBytes = 5 * 1024 * 1024;
const int maximumPhotoDimension = 1600;

class PhotoUploadException implements Exception {
  const PhotoUploadException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// Decodes the camera output instead of trusting its filename, fixes its EXIF
/// orientation and always returns a real JPEG accepted by Storage and Sharp.
Uint8List preparePhotoForUpload(Uint8List sourceBytes) {
  if (sourceBytes.isEmpty) {
    throw const PhotoUploadException(
      'Çekilen fotoğraf boş. Lütfen yeniden çek.',
    );
  }

  image.Image? decoded;
  try {
    decoded = image.decodeImage(sourceBytes);
  } catch (_) {
    throw const PhotoUploadException(
      'Fotoğraf biçimi okunamadı. Lütfen kamerayla yeniden çek.',
    );
  }
  if (decoded == null) {
    throw const PhotoUploadException(
      'Fotoğraf biçimi okunamadı. Lütfen kamerayla yeniden çek.',
    );
  }

  var prepared = image.bakeOrientation(decoded);
  if (prepared.width > maximumPhotoDimension ||
      prepared.height > maximumPhotoDimension) {
    prepared = image.copyResize(
      prepared,
      width: prepared.width >= prepared.height ? maximumPhotoDimension : null,
      height: prepared.height > prepared.width ? maximumPhotoDimension : null,
      interpolation: image.Interpolation.average,
    );
  }

  for (final quality in const [84, 76, 68, 60]) {
    final jpeg = image.encodeJpg(prepared, quality: quality);
    if (jpeg.lengthInBytes < maximumPhotoBytes) return jpeg;
  }

  throw const PhotoUploadException(
    'Fotoğraf 5 MB sınırına indirilemedi. Lütfen yeniden çek.',
  );
}

class PhotoUploadReceipt {
  const PhotoUploadReceipt({
    required this.photoId,
    required this.objectKey,
    required this.expiresAt,
  });

  final String photoId;
  final String objectKey;
  final DateTime expiresAt;
}

abstract interface class PhotoService {
  /// Accepts camera bytes only. Gallery selection belongs outside this API.
  Future<PhotoUploadReceipt> uploadCameraPhoto({
    required Uint8List jpegBytes,
    required String groupId,
    required String prayer,
    required String idempotencyKey,
  });
}
