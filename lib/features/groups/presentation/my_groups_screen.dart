import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/repository_provider.dart';
import '../../../core/domain/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive_page.dart';
import '../../../core/widgets/group_avatar.dart';

class MyGroupsScreen extends ConsumerStatefulWidget {
  const MyGroupsScreen({super.key});

  @override
  ConsumerState<MyGroupsScreen> createState() => _MyGroupsScreenState();
}

class _MyGroupsScreenState extends ConsumerState<MyGroupsScreen> {
  late Future<List<GroupSummary>> _groups;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _groups = ref.read(appRepositoryProvider).myGroups();
  }

  Future<void> _refresh() async {
    final next = ref.read(appRepositoryProvider).myGroups();
    setState(() => _groups = next);
    await next;
  }

  @override
  Widget build(BuildContext context) => AdaptivePage(
    title: 'Gruplarım',
    trailing: IconButton(
      tooltip: 'Yeni grup oluştur',
      onPressed: () async {
        final created = await context.push<bool>('/home/create-group');
        if (created == true && mounted) await _refresh();
      },
      icon: const Icon(Icons.add_rounded),
    ),
    body: FutureBuilder<List<GroupSummary>>(
      future: _groups,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        if (snapshot.hasError) {
          return _GroupsState(
            icon: Icons.cloud_off_outlined,
            title: 'Grupların yüklenemedi',
            detail: 'Bağlantını kontrol edip tekrar deneyebilirsin.',
            action: 'Tekrar dene',
            onAction: () => setState(_reload),
          );
        }
        final groups = snapshot.data ?? const <GroupSummary>[];
        if (groups.isEmpty) {
          return _GroupsState(
            icon: Icons.groups_outlined,
            title: 'Henüz bir grubun yok',
            detail:
                'Sana uygun bir gruba katılabilir veya kendi grubunu kurabilirsin.',
            action: 'Grupları keşfet',
            onAction: () => context.go('/home'),
          );
        }
        return RefreshIndicator.adaptive(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
            children: <Widget>[
              Text(
                '${groups.length} aktif grup',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              ...groups.indexed.map(
                (entry) => TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 260 + entry.$1 * 70),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 10 * (1 - value)),
                      child: child,
                    ),
                  ),
                  child: _GroupRow(
                    group: entry.$2,
                    onTap: () async {
                      await context.push<void>('/home/groups/${entry.$2.id}');
                      if (mounted) await _refresh();
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group, required this.onTap});
  final GroupSummary group;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: <Widget>[
          GroupAvatar(group: group, size: 52),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  group.name,
                  style: const TextStyle(
                    color: AppColors.brown,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${group.activeMemberCount} aktif üye · ${group.prayers.map((prayer) => prayer.label).join(', ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    ),
  );
}

class _GroupsState extends StatelessWidget {
  const _GroupsState({
    required this.icon,
    required this.title,
    required this.detail,
    required this.action,
    required this.onAction,
  });
  final IconData icon;
  final String title;
  final String detail;
  final String action;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 44, color: AppColors.green),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          AdaptivePrimaryButton(label: action, onPressed: onAction),
        ],
      ),
    ),
  );
}
