import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/data/repository_provider.dart';
import '../../../core/domain/models.dart';
import '../../../core/services/adhan_prayer_time_service.dart';
import '../../../core/services/demo_session_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive_page.dart';
import '../../../core/widgets/group_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Future<List<GroupSummary>> _myGroups;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _myGroups = ref.read(appRepositoryProvider).myGroups();
  }

  Future<void> _refresh() async {
    final next = ref.read(appRepositoryProvider).myGroups();
    setState(() {
      _myGroups = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) => AdaptivePage(
    body: RefreshIndicator.adaptive(
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _TopBar(),
                  const SizedBox(height: 18),
                  const _PrayerCard(),
                  const SizedBox(height: 24),
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SectionTitle('Gruplarım'),
                            SizedBox(height: 3),
                            Text(
                              'Dahil olduğun namaz halkaları',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Yeni grup oluştur',
                        child: Material(
                          color: AppColors.orange,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () async {
                              final created = await context.push<bool>(
                                '/home/create-group',
                              );
                              if (created == true && mounted) {
                                setState(_reload);
                              }
                            },
                            child: const SizedBox.square(
                              dimension: 46,
                              child: Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          FutureBuilder<List<GroupSummary>>(
            future: _myGroups,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverPadding(
                  padding: EdgeInsets.fromLTRB(18, 12, 18, 120),
                  sliver: SliverToBoxAdapter(child: _GroupSkeleton()),
                );
              }
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _MessageState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Grupların yüklenemedi',
                    message: 'Bağlantını kontrol edip tekrar deneyebilirsin.',
                    action: 'Tekrar dene',
                    onTap: () => setState(_reload),
                  ),
                );
              }
              final groups = snapshot.data ?? const <GroupSummary>[];
              if (groups.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
                    child: _NoGroupsCard(
                      onCreateGroup: () async {
                        final created = await context.push<bool>(
                          '/home/create-group',
                        );
                        if (created == true && mounted) {
                          setState(_reload);
                        }
                      },
                      onExploreGroups: () => context.go('/group'),
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == groups.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Center(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.brown,
                                side: const BorderSide(
                                  color: AppColors.line,
                                  width: 1.2,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () => context.go('/group'),
                              icon: const Icon(
                                Icons.explore_outlined,
                                size: 18,
                              ),
                              label: const Text(
                                'Daha fazla grup keşfet',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        );
                      }
                      final group = groups[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GroupCard(
                          group: group,
                          onTap: () async {
                            await context.push('/home/groups/${group.id}');
                            if (mounted) setState(_reload);
                          },
                        ),
                      );
                    },
                    childCount: groups.length + 1,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _NoGroupsCard extends StatelessWidget {
  const _NoGroupsCard({
    required this.onCreateGroup,
    required this.onExploreGroups,
  });

  final VoidCallback onCreateGroup;
  final VoidCallback onExploreGroups;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.line, width: .8),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0C5B3E2B),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: AppColors.greenMist,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.groups_outlined,
              color: AppColors.brown,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Henüz bir grubun yok',
            style: TextStyle(
              color: AppColors.brown,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Namazlarını cemaat şuuruyla vaktinde kılmak için sana uygun bir gruba dahil olabilir veya arkadaşlarınla kendi grubunu kurabilirsin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: onCreateGroup,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text(
                    'Grup Kur',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brown,
                    side: const BorderSide(
                      color: AppColors.brown,
                      width: 1.2,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: onExploreGroups,
                  icon: const Icon(Icons.search_rounded, size: 20),
                  label: const Text(
                    'Gruba Dahil Ol',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final user = Firebase.apps.isNotEmpty
        ? FirebaseAuth.instance.currentUser
        : null;
    if (user == null) {
      return AnimatedBuilder(
        animation: DemoSessionController.instance,
        builder: (context, _) {
          final fullName = DemoSessionController.instance.displayName.trim();
          final firstName = fullName.split(RegExp(r'\s+')).firstOrNull;
          return _content(
            firstName == null || firstName.isEmpty ? 'Misafir' : firstName,
          );
        },
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.doc('users/${user.uid}').snapshots(),
      builder: (context, snapshot) {
        final fullName =
            snapshot.data?.data()?['displayName'] as String? ?? 'Misafir';
        final firstName = fullName.trim().split(RegExp(r'\s+')).firstOrNull;
        return _content(
          firstName == null || firstName.isEmpty ? 'Misafir' : firstName,
        );
      },
    );
  }

  Widget _content(String name) => Row(
    children: <Widget>[
      Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppColors.brown,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.nights_stay_rounded,
          color: Colors.white,
          size: 21,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Hayırlı günler',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              name,
              style: const TextStyle(
                color: AppColors.brown,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.line),
        ),
        child: const Icon(
          Icons.notifications_none_rounded,
          color: AppColors.brown,
          size: 21,
        ),
      ),
    ],
  );
}

class _PrayerCard extends StatefulWidget {
  const _PrayerCard();

  @override
  State<_PrayerCard> createState() => _PrayerCardState();
}

class _PrayerCardState extends State<_PrayerCard> {
  Future<({Prayer prayer, DateTime startsAt, String timezone})?>? _next;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _next = _load();
    DemoSessionController.instance.addListener(_reloadDemoSchedule);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    DemoSessionController.instance.removeListener(_reloadDemoSchedule);
    super.dispose();
  }

  void _reloadDemoSchedule() {
    if (Firebase.apps.isNotEmpty || !mounted) return;
    setState(() => _next = _load());
  }

  Future<({Prayer prayer, DateTime startsAt, String timezone})?> _load() async {
    final user = Firebase.apps.isNotEmpty
        ? FirebaseAuth.instance.currentUser
        : null;
    if (user == null) {
      const timezoneName = 'Europe/Istanbul';
      tz_data.initializeTimeZones();
      final location = tz.getLocation(timezoneName);
      final now = tz.TZDateTime.now(location);
      final city = DemoSessionController.instance.city
          .trim()
          .toLowerCase()
          .replaceAll('ı', 'i');
      final coordinates = switch (city) {
        'ankara' => (39.9334, 32.8597),
        'bursa' => (40.1950, 29.0600),
        'izmir' => (38.4237, 27.1428),
        'konya' => (37.8746, 32.4932),
        _ => (41.0082, 28.9784),
      };
      final service = AdhanPrayerTimeService();
      for (var dayOffset = 0; dayOffset <= 1; dayOffset++) {
        final schedule = await service.scheduleFor(
          date: now.add(Duration(days: dayOffset)),
          latitude: coordinates.$1,
          longitude: coordinates.$2,
          madhhab: DemoSessionController.instance.madhhab,
          timezone: timezoneName,
        );
        final upcoming = schedule.windows
            .where((window) => window.startsAt.isAfter(now))
            .firstOrNull;
        if (upcoming != null) {
          return (
            prayer: upcoming.prayer,
            startsAt: upcoming.startsAt,
            timezone: timezoneName,
          );
        }
      }
      return null;
    }
    final firestore = FirebaseFirestore.instance;
    final profile = await firestore.doc('users/${user.uid}').get();
    final timezoneName =
        profile.data()?['timezone'] as String? ?? 'Europe/Istanbul';
    tz_data.initializeTimeZones();
    final location = tz.getLocation(timezoneName);
    final now = tz.TZDateTime.now(location);
    String key(tz.TZDateTime date) =>
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final documents = await Future.wait([
      firestore.doc('users/${user.uid}/prayerDays/${key(now)}').get(),
      firestore
          .doc(
            'users/${user.uid}/prayerDays/${key(now.add(const Duration(days: 1)))}',
          )
          .get(),
    ]);
    final candidates =
        <({Prayer prayer, DateTime startsAt, String timezone})>[];
    for (final document in documents) {
      final windows = document.data()?['windows'] as Map<String, dynamic>?;
      if (windows == null) continue;
      for (final prayer in Prayer.values) {
        final window = windows[prayer.name] as Map<String, dynamic>?;
        final startsAt = window?['startsAt'] as Timestamp?;
        if (startsAt != null && startsAt.toDate().isAfter(DateTime.now())) {
          candidates.add((
            prayer: prayer,
            startsAt: startsAt.toDate(),
            timezone: timezoneName,
          ));
        }
      }
    }
    candidates.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return candidates.firstOrNull;
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<({Prayer prayer, DateTime startsAt, String timezone})?>(
        future: _next,
        builder: (context, snapshot) {
          final next = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _PrayerCardSkeleton();
          }
          if (next == null) {
            return _content(
              prayerLabel: 'VAKİTLER HAZIRLANIYOR',
              time: '--:--',
              remaining: 'Yenilemek için profili aç',
            );
          }
          if (!next.startsAt.isAfter(DateTime.now())) {
            _next = _load();
          }
          final difference = next.startsAt.difference(DateTime.now());
          final hours = difference.inHours;
          final minutes = difference.inMinutes.remainder(60).clamp(0, 59);
          final remaining = hours > 0
              ? '$hours sa $minutes dk kaldı'
              : '${difference.inMinutes.clamp(0, 59)} dk kaldı';
          final time = DateFormat('HH:mm').format(
            tz.TZDateTime.from(next.startsAt, tz.getLocation(next.timezone)),
          );
          return _content(
            prayerLabel: '${next.prayer.label.toUpperCase()} VAKTİNE',
            time: time,
            remaining: remaining,
          );
        },
      );

  Widget _content({
    required String prayerLabel,
    required String time,
    required String remaining,
  }) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppColors.green,
      borderRadius: BorderRadius.circular(32),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x2E1E3A2F),
          blurRadius: 28,
          offset: Offset(0, 14),
        ),
      ],
    ),
    child: Stack(
      children: <Widget>[
        Positioned(
          right: -24,
          top: -24,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .06),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    prayerLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .65,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wb_twilight_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Text(
                    time,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      height: .9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2.4,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    remaining,
                    style: const TextStyle(
                      color: AppColors.brownPale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

class _PrayerCardSkeleton extends StatelessWidget {
  const _PrayerCardSkeleton();

  @override
  Widget build(BuildContext context) => Container(
    height: 151,
    decoration: BoxDecoration(
      color: AppColors.brownPale,
      borderRadius: BorderRadius.circular(32),
    ),
  );
}

class _GroupSkeleton extends StatefulWidget {
  const _GroupSkeleton();

  @override
  State<_GroupSkeleton> createState() => _GroupSkeletonState();
}

class _GroupSkeletonState extends State<_GroupSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => Opacity(
      opacity: .45 + (_controller.value * .45),
      child: Column(
        children: List<Widget>.generate(
          2,
          (index) => Container(
            height: 140,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.line),
            ),
          ),
        ),
      ),
    ),
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 110),
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
            child: Icon(icon, color: AppColors.green, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.brown,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.45),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: 12),
            AdaptiveSecondaryButton(label: action!, onPressed: onTap),
          ],
        ],
      ),
    ),
  );
}
