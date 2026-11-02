import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/repository_provider.dart';
import '../../../core/services/photo_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive_page.dart';

class PhotoCheckinScreen extends ConsumerStatefulWidget {
  const PhotoCheckinScreen({
    required this.groupId,
    required this.prayer,
    super.key,
  });
  final String groupId;
  final String prayer;
  @override
  ConsumerState<PhotoCheckinScreen> createState() => _PhotoCheckinScreenState();
}

class _PhotoCheckinScreenState extends ConsumerState<PhotoCheckinScreen> {
  Uint8List? _photo;
  bool _sending = false;
  Future<void> _takePhoto() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 84,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (mounted) {
        setState(() => _photo = bytes);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kamera açılamadı. Kamera iznini kontrol et.'),
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (_photo == null || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(photoServiceProvider)
          .uploadCameraPhoto(
            jpegBytes: _photo!,
            groupId: widget.groupId,
            prayer: widget.prayer,
            idempotencyKey: const Uuid().v4(),
          );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on PhotoUploadException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotoğraf gönderilemedi. Lütfen tekrar dene.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdaptivePage(
    title: 'Fotoğrafla doğrula',
    body: Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Kamerayla çektiğin fotoğraf yalnızca grup üyelerine görünür ve 12 saat sonra silinir.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 22),
          Expanded(
            child: GestureDetector(
              onTap: _takePhoto,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.greenPale,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.line),
                ),
                child: _photo == null
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              size: 44,
                              color: AppColors.green,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Fotoğraf çek',
                              style: TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Image.memory(_photo!, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AdaptivePrimaryButton(
            label: _sending
                ? 'Gönderiliyor…'
                : _photo == null
                ? 'Kamerayı aç'
                : 'Fotoğrafı gönder',
            onPressed: _sending
                ? null
                : _photo == null
                ? _takePhoto
                : _submit,
          ),
        ],
      ),
    ),
  );
}
