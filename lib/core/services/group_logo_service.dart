import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class GroupLogoService {
  GroupLogoService({
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

  Future<String> upload({
    required String groupId,
    required Uint8List jpegBytes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Logo yüklemek için oturum gerekli.');
    }
    if (jpegBytes.isEmpty || jpegBytes.lengthInBytes >= 2 * 1024 * 1024) {
      throw ArgumentError('Logo boş olamaz ve 2 MB sınırını aşamaz.');
    }

    final objectKey =
        'group-logos/$groupId/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final reference = _storage.ref(objectKey);
    await reference.putData(
      jpegBytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    try {
      await _functions.httpsCallable('setGroupLogo').call(<String, Object?>{
        'groupId': groupId,
        'objectKey': objectKey,
      });
      return objectKey;
    } catch (_) {
      await reference.delete().catchError((_) {});
      rethrow;
    }
  }
}
