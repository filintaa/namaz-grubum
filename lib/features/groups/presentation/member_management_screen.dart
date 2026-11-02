import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/repository_provider.dart';
import '../../../core/domain/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive_page.dart';

class MemberManagementScreen extends ConsumerStatefulWidget {
  const MemberManagementScreen({
    required this.groupId,
    required this.currentRole,
    super.key,
  });

  final String groupId;
  final GroupRole currentRole;

  @override
  ConsumerState<MemberManagementScreen> createState() =>
      _MemberManagementScreenState();
}

class _MemberManagementScreenState
    extends ConsumerState<MemberManagementScreen> {
  late Future<List<GroupMember>> _members = _load();
  String? _busyId;

  Future<List<GroupMember>> _load() =>
      ref.read(appRepositoryProvider).groupMembers(widget.groupId);

  void _refresh() => setState(() => _members = _load());

  Future<void> _changeRole(GroupMember member, GroupRole role) async {
    setState(() => _busyId = member.id);
    try {
      await ref
          .read(appRepositoryProvider)
          .setMemberRole(
            groupId: widget.groupId,
            targetUserId: member.id,
            role: role,
          );
      if (mounted) _refresh();
    } catch (_) {
      if (mounted) _showError('Üye rolü değiştirilemedi.');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _remove(GroupMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Üyeyi gruptan çıkar'),
        content: Text(
          '${member.displayName} gruptan çıkarılacak. Yeniden katılmak isterse normal katılım sürecini kullanabilir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: const Text('Gruptan çıkar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyId = member.id);
    try {
      await ref
          .read(appRepositoryProvider)
          .removeGroupMember(groupId: widget.groupId, targetUserId: member.id);
      if (mounted) _refresh();
    } catch (_) {
      if (mounted) _showError('Üye gruptan çıkarılamadı.');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _suspend(GroupMember member, int days) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Üyeyi geçici uzaklaştır'),
        content: Text(
          '${member.displayName} $days gün boyunca gruba yeniden katılamayacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Uzaklaştır'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyId = member.id);
    try {
      await ref
          .read(appRepositoryProvider)
          .suspendGroupMember(
            groupId: widget.groupId,
            targetUserId: member.id,
            durationDays: days,
          );
      if (mounted) _refresh();
    } catch (_) {
      if (mounted) _showError('Üye geçici olarak uzaklaştırılamadı.');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _showError(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  bool _canRemove(GroupMember member) =>
      !member.isCurrentUser &&
      member.role != GroupRole.owner &&
      (widget.currentRole == GroupRole.owner ||
          member.role == GroupRole.member);

  @override
  Widget build(BuildContext context) => AdaptivePage(
    title: 'Üyeleri yönet',
    body: FutureBuilder<List<GroupMember>>(
      future: _members,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        if (snapshot.hasError) {
          return Center(
            child: AdaptiveSecondaryButton(
              label: 'Tekrar dene',
              onPressed: _refresh,
            ),
          );
        }
        final members = snapshot.data ?? const <GroupMember>[];
        return RefreshIndicator.adaptive(
          onRefresh: () async {
            final next = _load();
            setState(() => _members = next);
            await next;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
            children: [
              const Text(
                'Sahip rolleri düzenleyebilir. Çıkarılan üyeler 7 gün, geçici uzaklaştırılan üyeler seçilen süre boyunca yeniden katılamaz.',
                style: TextStyle(color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 20),
              ...members.map(
                (member) => _ManagedMemberRow(
                  member: member,
                  busy: _busyId == member.id,
                  canChangeRole:
                      widget.currentRole == GroupRole.owner &&
                      !member.isCurrentUser &&
                      member.role != GroupRole.owner,
                  canRemove: _canRemove(member),
                  onMakeModerator: () =>
                      _changeRole(member, GroupRole.moderator),
                  onMakeMember: () => _changeRole(member, GroupRole.member),
                  onRemove: () => _remove(member),
                  onSuspend: (days) => _suspend(member, days),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _ManagedMemberRow extends StatelessWidget {
  const _ManagedMemberRow({
    required this.member,
    required this.busy,
    required this.canChangeRole,
    required this.canRemove,
    required this.onMakeModerator,
    required this.onMakeMember,
    required this.onRemove,
    required this.onSuspend,
  });

  final GroupMember member;
  final bool busy;
  final bool canChangeRole;
  final bool canRemove;
  final VoidCallback onMakeModerator;
  final VoidCallback onMakeMember;
  final VoidCallback onRemove;
  final ValueChanged<int> onSuspend;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 13),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.greenPale,
          child: Text(
            member.displayName.characters.first.toUpperCase(),
            style: const TextStyle(
              color: AppColors.green,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.isCurrentUser
                    ? '${member.displayName} (Sen)'
                    : member.displayName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${member.role.label}${member.location.isEmpty ? '' : ' · ${member.location}'}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        if (busy)
          const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          )
        else if (canChangeRole || canRemove)
          PopupMenuButton<String>(
            tooltip: 'Üye işlemleri',
            onSelected: (action) {
              if (action == 'moderator') onMakeModerator();
              if (action == 'member') onMakeMember();
              if (action == 'remove') onRemove();
              if (action.startsWith('suspend_')) {
                onSuspend(int.parse(action.substring('suspend_'.length)));
              }
            },
            itemBuilder: (context) => [
              if (canChangeRole && member.role == GroupRole.member)
                const PopupMenuItem(
                  value: 'moderator',
                  child: Text('Yönetici yap'),
                ),
              if (canChangeRole && member.role == GroupRole.moderator)
                const PopupMenuItem(value: 'member', child: Text('Üye yap')),
              if (canRemove)
                const PopupMenuItem(
                  value: 'suspend_1',
                  child: Text('1 gün uzaklaştır'),
                ),
              if (canRemove)
                const PopupMenuItem(
                  value: 'suspend_7',
                  child: Text('7 gün uzaklaştır'),
                ),
              if (canRemove)
                const PopupMenuItem(
                  value: 'suspend_30',
                  child: Text('30 gün uzaklaştır'),
                ),
              if (canRemove)
                PopupMenuItem(
                  value: 'remove',
                  child: Text(
                    'Gruptan çıkar',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
            ],
          ),
      ],
    ),
  );
}
