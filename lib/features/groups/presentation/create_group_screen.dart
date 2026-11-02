import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/data/repository_provider.dart';
import '../../../core/domain/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive_page.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _countryController = TextEditingController(text: 'TR');
  final _cityController = TextEditingController(text: 'İstanbul');
  final Set<Prayer> _prayers = <Prayer>{Prayer.fajr};
  VerificationType _verification = VerificationType.button;
  bool _approvalRequired = true;
  bool _saving = false;
  String? _error;
  Uint8List? _logoBytes;
  String _logoEmoji = '🌙';

  static const _logoEmojis = <String>[
    '🌙',
    '☀️',
    '🌿',
    '🕌',
    '⭐',
    '🤲',
    '🕊️',
    '🌅',
    '⏰',
    '💚',
    '✨',
    '📿',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_saving || _nameController.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final groupId = await ref
          .read(appRepositoryProvider)
          .createGroup(
            GroupDraft(
              name: _nameController.text.trim(),
              countryCode: _countryController.text.trim().toUpperCase(),
              city: _cityController.text.trim().isEmpty
                  ? null
                  : _cityController.text.trim(),
              prayers: _prayers,
              verificationType: _verification,
              joinApprovalRequired: _approvalRequired,
              logoEmoji: _logoBytes == null ? _logoEmoji : null,
            ),
          );
      if (_logoBytes != null) {
        try {
          await ref
              .read(groupLogoServiceProvider)
              .upload(groupId: groupId, jpegBytes: _logoBytes!);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Grup oluşturuldu; logo daha sonra eklenebilir.'),
              ),
            );
          }
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString().contains('resource-exhausted')
              ? 'En fazla 3 aktif gruba katılabilirsin.'
              : 'Grup oluşturulamadı. Lütfen tekrar dene.';
        });
      }
    }
  }

  Future<void> _pickLogo() async {
    Navigator.of(context).pop();
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 82,
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _logoBytes = bytes;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Fotoğraf arşivi açılamadı. İzni kontrol et.');
      }
    }
  }

  void _showLogoPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.warmWhite,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => _LogoPickerSheet(
        emojis: _logoEmojis,
        selectedEmoji: _logoBytes == null ? _logoEmoji : null,
        onPhoto: _pickLogo,
        onEmoji: (emoji) {
          Navigator.of(sheetContext).pop();
          setState(() {
            _logoEmoji = emoji;
            _logoBytes = null;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AdaptivePage(
    title: 'Grup Oluştur',
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
      children: <Widget>[
        const Text(
          'Grup adı',
          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        AdaptiveTextField(
          controller: _nameController,
          placeholder: 'Örn. Sabahın Gençleri',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            Expanded(
              child: AdaptiveTextField(
                controller: _countryController,
                placeholder: 'Ülke kodu',
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: AdaptiveTextField(
                controller: _cityController,
                placeholder: 'Şehir',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Grup logosu',
          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _showLogoPicker,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: <Widget>[
              Container(
                width: 76,
                height: 76,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.greenPale,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: AppColors.line),
                ),
                child: _logoBytes == null
                    ? Center(
                        child: Text(
                          _logoEmoji,
                          style: const TextStyle(fontSize: 34),
                        ),
                      )
                    : Image.memory(_logoBytes!, fit: BoxFit.cover),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Logo seç',
                      style: TextStyle(
                        color: AppColors.brown,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Fotoğraf yükle veya hazır simgelerden birini kullan.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Namazlar',
          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: Prayer.values.map((prayer) {
            final selected = _prayers.contains(prayer);
            return _PrayerChip(
              label: prayer.label,
              selected: selected,
              onTap: () => setState(() {
                if (!selected) {
                  _prayers.add(prayer);
                } else if (_prayers.length > 1) {
                  _prayers.remove(prayer);
                }
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Doğrulama',
          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        _SelectRow(
          title: 'Kıldım butonu',
          description: 'Üye vakit içinde tek dokunuşla tamamlar.',
          selected: _verification == VerificationType.button,
          onTap: () => setState(() => _verification = VerificationType.button),
        ),
        const SizedBox(height: 10),
        _SelectRow(
          title: 'Anlık fotoğraf',
          description: 'Yalnızca uygulama kamerası; 12 saatte silinir.',
          selected: _verification == VerificationType.photo,
          onTap: () => setState(() => _verification = VerificationType.photo),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: <Widget>[
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Katılım onayı',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Yeni üyeleri yönetici onaylasın.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: _approvalRequired,
                activeTrackColor: AppColors.green,
                onChanged: (value) => setState(() => _approvalRequired = value),
              ),
            ],
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: AppColors.error, fontSize: 13),
          ),
        ],
        const SizedBox(height: 28),
        AdaptivePrimaryButton(
          label: _saving ? 'Oluşturuluyor' : 'Grubu Oluştur',
          onPressed:
              _saving ||
                  _nameController.text.trim().isEmpty ||
                  _countryController.text.trim().length != 2
              ? null
              : _create,
        ),
      ],
    ),
  );
}

class _LogoPickerSheet extends StatelessWidget {
  const _LogoPickerSheet({
    required this.emojis,
    required this.selectedEmoji,
    required this.onPhoto,
    required this.onEmoji,
  });

  final List<String> emojis;
  final String? selectedEmoji;
  final VoidCallback onPhoto;
  final ValueChanged<String> onEmoji;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Grubuna bir karakter ver',
          style: TextStyle(
            color: AppColors.brown,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Fotoğraf seçebilir veya hazır simgelerden birini kullanabilirsin.',
          style: TextStyle(color: AppColors.muted, height: 1.35),
        ),
        const SizedBox(height: 18),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: onPhoto,
            borderRadius: BorderRadius.circular(22),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Icon(Icons.photo_library_outlined, color: AppColors.green),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Fotoğraflardan logo seç',
                      style: TextStyle(
                        color: AppColors.brown,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: emojis.length,
          itemBuilder: (context, index) {
            final emoji = emojis[index];
            final selected = emoji == selectedEmoji;
            return GestureDetector(
              onTap: () => onEmoji(emoji),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  color: selected ? AppColors.greenPale : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? AppColors.green : AppColors.line,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 25)),
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}

class _SelectRow extends StatelessWidget {
  const _SelectRow({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? AppColors.greenPale : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: selected ? AppColors.green : AppColors.line),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.brown,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? AppColors.green : AppColors.muted,
          ),
        ],
      ),
    ),
  );
}

class _PrayerChip extends StatelessWidget {
  const _PrayerChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.greenPale : Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: selected ? AppColors.green : AppColors.line),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.green : AppColors.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}
