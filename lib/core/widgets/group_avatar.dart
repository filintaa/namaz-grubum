import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../theme/app_theme.dart';

class GroupAvatar extends StatefulWidget {
  const GroupAvatar({required this.group, this.size = 50, super.key});

  final GroupSummary group;
  final double size;

  @override
  State<GroupAvatar> createState() => _GroupAvatarState();
}

class _GroupAvatarState extends State<GroupAvatar> {
  Future<Uint8List?>? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant GroupAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.logoObjectKey != widget.group.logoObjectKey) _load();
  }

  void _load() {
    final key = widget.group.logoObjectKey;
    _image = key == null
        ? null
        : FirebaseStorage.instance.ref(key).getData(2 * 1024 * 1024);
  }

  @override
  Widget build(BuildContext context) => Container(
    width: widget.size,
    height: widget.size,
    clipBehavior: Clip.antiAlias,
    decoration: const BoxDecoration(
      color: AppColors.greenPale,
      shape: BoxShape.circle,
    ),
    child: _image == null
        ? _fallback()
        : FutureBuilder<Uint8List?>(
            future: _image,
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              if (bytes == null) return _fallback();
              return Image.memory(bytes, fit: BoxFit.cover);
            },
          ),
  );

  Widget _fallback() {
    final emoji = widget.group.logoEmoji;
    if (emoji != null && emoji.isNotEmpty) {
      return Center(
        child: Text(emoji, style: TextStyle(fontSize: widget.size * .48)),
      );
    }
    return Icon(
      Icons.wb_twilight_rounded,
      color: AppColors.green,
      size: widget.size * .48,
    );
  }
}
