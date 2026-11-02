import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/repository_provider.dart';
import '../../../core/domain/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive_page.dart';

class GroupSettingsScreen extends ConsumerStatefulWidget {
  const GroupSettingsScreen({
    required this.group,
    required this.role,
    super.key,
  });

  final GroupSummary group;
  final GroupRole role;

  @override
  ConsumerState<GroupSettingsScreen> createState() =>
      _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.group.name,
  );
  late final Set<Prayer> _prayers = widget.group.prayers.toSet();
  late bool _approval = widget.group.joinApprovalRequired;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _name.text.trim().isEmpty || _prayers.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(appRepositoryProvider)
          .updateGroup(
            groupId: widget.group.id,
            name: _name.text.trim(),
            prayers: _prayers,
            joinApprovalRequired: _approval,
          );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ayarlar kaydedilemedi. Tekrar deneyin.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gruptan ayrıl'),
        content: const Text(
          'Bu grubun günlük akışını ve hatırlatmalarını artık göremezsin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ayrıl'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(appRepositoryProvider).leaveGroup(widget.group.id);
      if (mounted) {
        Navigator.pop(context, 'left');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.toString().contains('sahipliği')
                  ? 'Grup sahibi önce sahipliği devretmelidir.'
                  : 'Gruptan ayrılamadın.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _transferOwnership() async {
    try {
      final members =
          (await ref.read(appRepositoryProvider).groupMembers(widget.group.id))
              .where((member) => !member.isCurrentUser)
              .toList();
      if (!mounted) return;
      if (members.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sahipliği devredebileceğin başka aktif üye yok.'),
          ),
        );
        return;
      }
      String? selectedId;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Grup sahipliğini devret'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Yeni sahip grup ayarlarının tam kontrolünü alır. Sen yönetici olarak kalırsın.',
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: RadioGroup<String>(
                      groupValue: selectedId,
                      onChanged: (value) =>
                          setDialogState(() => selectedId = value),
                      child: ListView(
                        shrinkWrap: true,
                        children: members
                            .map(
                              (member) => RadioListTile<String>(
                                value: member.id,
                                title: Text(member.displayName),
                                subtitle: member.location.isEmpty
                                    ? null
                                    : Text(member.location),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: selectedId == null
                    ? null
                    : () => Navigator.pop(context, true),
                child: const Text('Sahipliği devret'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || selectedId == null || !mounted) return;
      await ref
          .read(appRepositoryProvider)
          .transferGroupOwnership(
            groupId: widget.group.id,
            targetUserId: selectedId!,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sahiplik devredilemedi. Tekrar dene.')),
        );
      }
    }
  }

  Future<void> _archive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grubu arşivle'),
        content: const Text(
          'Grup keşiften ve üyelerin aktif grup listesinden kaldırılır. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: const Text('Grubu arşivle'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(appRepositoryProvider).archiveGroup(widget.group.id);
      if (mounted) context.go('/group');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grup arşivlenemedi. Tekrar dene.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AdaptivePage(
    title: 'Grup ayarları',
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
      children: [
        if (!widget.role.canManage)
          const Padding(
            padding: EdgeInsets.only(bottom: 18),
            child: Text(
              'Bu grubun üyesisin. Grup bilgilerini yalnızca yöneticiler değiştirebilir.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        if (widget.role.canManage) ...[
          const SectionTitle('Yönetim'),
          const SizedBox(height: 8),
          _ManagementLink(
            icon: Icons.group_outlined,
            label: 'Üyeleri yönet',
            onTap: () => context.push<void>(
              '/home/groups/${widget.group.id}/members',
              extra: widget.role,
            ),
          ),
          const SizedBox(height: 24),
          const SectionTitle('Grup bilgileri'),
          const SizedBox(height: 10),
          AdaptiveTextField(controller: _name, placeholder: 'Grup adı'),
          const SizedBox(height: 24),
          const Text(
            'Takip edilen vakitler',
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: Prayer.values
                .map(
                  (prayer) => FilterChip(
                    label: Text(prayer.label),
                    selected: _prayers.contains(prayer),
                    onSelected: (selected) => setState(
                      () => selected
                          ? _prayers.add(prayer)
                          : _prayers.remove(prayer),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Katılım isteklerini onayla'),
            subtitle: const Text('Yeni üyeler yönetici onayıyla katılır.'),
            value: _approval,
            activeThumbColor: AppColors.green,
            onChanged: (value) => setState(() => _approval = value),
          ),
          const SizedBox(height: 20),
          AdaptivePrimaryButton(
            label: _saving ? 'Kaydediliyor…' : 'Değişiklikleri kaydet',
            onPressed: _saving ? null : _save,
          ),
          if (widget.role == GroupRole.owner) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _transferOwnership,
              icon: const Icon(Icons.manage_accounts_outlined),
              label: const Text('Grup sahipliğini devret'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _archive,
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Grubu arşivle'),
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            ),
          ],
        ],
        const SizedBox(height: 28),
        const Divider(color: AppColors.line),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _leave,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Gruptan ayrıl'),
          style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
        ),
      ],
    ),
  );
}

class _ManagementLink extends StatelessWidget {
  const _ManagementLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    ),
  );
}
