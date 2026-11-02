import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/repository_provider.dart';
import '../../../core/domain/models.dart';
import '../../../core/theme/app_theme.dart';

class PrayerPhotoStrip extends ConsumerStatefulWidget {
  const PrayerPhotoStrip({
    required this.groupId,
    required this.prayer,
    required this.members,
    super.key,
  });

  final String groupId;
  final Prayer prayer;
  final List<GroupMember> members;

  @override
  ConsumerState<PrayerPhotoStrip> createState() => _PrayerPhotoStripState();
}

class _PrayerPhotoStripState extends ConsumerState<PrayerPhotoStrip> {
  late Future<List<PrayerPhoto>> _photos;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _photos = ref
        .read(appRepositoryProvider)
        .prayerPhotos(groupId: widget.groupId, prayer: widget.prayer);
  }

  String _memberName(String userId) =>
      widget.members
          .where((member) => member.id == userId)
          .map((member) => member.isCurrentUser ? 'Sen' : member.displayName)
          .firstOrNull ??
      'Grup üyesi';

  String _remaining(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return 'Silinmek üzere';
    if (remaining.inHours >= 1) {
      return '${remaining.inHours} sa ${remaining.inMinutes.remainder(60)} dk sonra silinir';
    }
    return '${remaining.inMinutes.clamp(1, 59)} dk sonra silinir';
  }

  Future<void> _open(PrayerPhoto photo) async {
    final bytes = FirebaseStorage.instance
        .ref(photo.objectKey)
        .getData(5 * 1024 * 1024);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 1,
              child: FutureBuilder<Uint8List?>(
                future: bytes,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator.adaptive(),
                    );
                  }
                  return Image.memory(snapshot.data!, fit: BoxFit.cover);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _memberName(photo.userId),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _remaining(photo.expiresAt),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _report(photo);
                    },
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: const Text('Şikâyet et'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _report(PrayerPhoto photo) async {
    String reason = 'uygunsuz';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Fotoğrafı şikâyet et'),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                <({String value, String label})>[
                      (value: 'uygunsuz', label: 'Uygunsuz içerik'),
                      (value: 'yaniltici', label: 'Yanıltıcı doğrulama'),
                      (value: 'diger', label: 'Diğer'),
                    ]
                    .map(
                      (option) => ChoiceChip(
                        label: Text(option.label),
                        selected: reason == option.value,
                        onSelected: (_) =>
                            setDialogState(() => reason = option.value),
                      ),
                    )
                    .toList(),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Gönder'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(appRepositoryProvider)
          .reportPhoto(photoId: photo.id, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şikâyetin incelemeye gönderildi.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.toString().contains('already-exists')
                  ? 'Bu fotoğrafı daha önce şikâyet ettin.'
                  : 'Şikâyet gönderilemedi.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<PrayerPhoto>>(
    future: _photos,
    builder: (context, snapshot) {
      final photos = snapshot.data ?? const <PrayerPhoto>[];
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const SizedBox(
          height: 96,
          child: Center(child: CircularProgressIndicator.adaptive()),
        );
      }
      if (snapshot.hasError || photos.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Bugünün fotoğrafları',
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) => _PhotoThumb(
                photo: photos[index],
                onTap: () => _open(photos[index]),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.photo, required this.onTap});
  final PrayerPhoto photo;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Hero(
      tag: 'prayer-photo-${photo.id}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox.square(
          dimension: 92,
          child: FutureBuilder<Uint8List?>(
            future: FirebaseStorage.instance
                .ref(photo.objectKey)
                .getData(800 * 1024),
            builder: (context, snapshot) => snapshot.hasData
                ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                : const ColoredBox(
                    color: AppColors.greenPale,
                    child: Icon(Icons.photo_outlined, color: AppColors.green),
                  ),
          ),
        ),
      ),
    ),
  );
}
