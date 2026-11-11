import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/repository_provider.dart';
import '../../../core/domain/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive_page.dart';
import '../../../core/widgets/group_card.dart';

class MyGroupsScreen extends ConsumerStatefulWidget {
  const MyGroupsScreen({super.key});

  @override
  ConsumerState<MyGroupsScreen> createState() => _MyGroupsScreenState();
}

class _MyGroupsScreenState extends ConsumerState<MyGroupsScreen> {
  late Future<List<GroupSummary>> _groups;
  String _query = '';
  String? _nextCursor;
  bool _loadingMore = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _groups = _firstPage('');
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<List<GroupSummary>> _firstPage(String query) async {
    final page = await ref
        .read(appRepositoryProvider)
        .discoverGroupPage(query: query);
    _nextCursor = page.nextCursor;
    return page.groups;
  }

  void _search(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _query = query;
        _nextCursor = null;
        _groups = _firstPage(query);
      });
    });
  }

  Future<void> _refresh() async {
    final next = _firstPage(_query);
    setState(() {
      _groups = next;
    });
    await next;
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (_loadingMore || cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final current = await _groups;
      final page = await ref
          .read(appRepositoryProvider)
          .discoverGroupPage(query: _query, cursor: cursor);
      if (!mounted) return;
      setState(() {
        _nextCursor = page.nextCursor;
        _groups = Future.value(<GroupSummary>[...current, ...page.groups]);
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdaptivePage(
    title: 'Gruplarım',
    trailing: IconButton(
      tooltip: 'Yeni grup oluştur',
      onPressed: () async {
        final created = await context.push<bool>('/home/create-group');
        if (created == true && mounted) _search('');
      },
      icon: const Icon(Icons.add_rounded),
    ),
    body: RefreshIndicator.adaptive(
      onRefresh: _refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 200) {
            _loadMore();
          }
          return false;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AdaptiveTextField(
                      placeholder: 'Grup, şehir veya ülke ara',
                      prefixIcon: Icons.search_rounded,
                      onChanged: _search,
                    ),
                    const SizedBox(height: 22),
                    const SectionTitle('Sana uygun gruplar'),
                    const SizedBox(height: 4),
                    const Text(
                      'Aynı vakitte aynı niyette buluş.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            FutureBuilder<List<GroupSummary>>(
              future: _groups,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverPadding(
                    padding: EdgeInsets.fromLTRB(18, 8, 18, 120),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator.adaptive(),
                        ),
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _DiscoverState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Gruplar yüklenemedi',
                      detail: 'Bağlantını kontrol edip tekrar deneyebilirsin.',
                      action: 'Tekrar dene',
                      onAction: () => _search(''),
                    ),
                  );
                }
                final groups = snapshot.data ?? const <GroupSummary>[];
                if (groups.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _DiscoverState(
                      icon: Icons.search_off_rounded,
                      title: 'Eşleşen grup yok',
                      detail:
                          'Başka bir grup adı, şehir veya ülke arayabilirsin.',
                      action: 'Aramayı temizle',
                      onAction: () => _search(''),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final group = groups[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GroupCard(
                            group: group,
                            onTap: () async {
                              await context.push('/home/groups/${group.id}');
                              if (mounted) _search(_query);
                            },
                          ),
                        );
                      },
                      childCount: groups.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _DiscoverState extends StatelessWidget {
  const _DiscoverState({
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
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.greenPale,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: AppColors.green),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.brown,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.45),
          ),
          const SizedBox(height: 16),
          AdaptiveSecondaryButton(label: action, onPressed: onAction),
        ],
      ),
    ),
  );
}
