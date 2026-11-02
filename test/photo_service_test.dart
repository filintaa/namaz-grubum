import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:namaz_grubum/core/services/photo_service.dart';

void main() {
  test('camera image is normalized to a valid JPEG within upload limits', () {
    final source = image.Image(width: 2200, height: 1200);
    image.fill(source, color: image.ColorRgb8(18, 96, 64));

    final result = preparePhotoForUpload(
      Uint8List.fromList(image.encodePng(source)),
    );
    final decoded = image.decodeJpg(result);

    expect(result.take(2), [0xff, 0xd8]);
    expect(decoded, isNotNull);
    expect(decoded!.width, maximumPhotoDimension);
    expect(decoded.height, lessThanOrEqualTo(maximumPhotoDimension));
    expect(result.lengthInBytes, lessThan(maximumPhotoBytes));
  });

  test('invalid camera bytes produce an actionable error', () {
    expect(
      () => preparePhotoForUpload(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<PhotoUploadException>()),
    );
  });
}
