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
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive_page.dart';
import '../../../core/widgets/group_avatar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
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
    body: CustomScrollView(
      physics: const BouncingScrollPhysics(),
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
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AdaptiveTextField(
                        placeholder: 'Grup, şehir veya ülke ara',
                        prefixIcon: Icons.search_rounded,
                        onChanged: _search,
                      ),
                    ),
                    const SizedBox(width: 10),
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
                            if (created == true && mounted) _search('');
                          },
                          child: const SizedBox.square(
                            dimension: 56,
                            child: Icon(Icons.add_rounded, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
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
                padding: EdgeInsets.fromLTRB(18, 12, 18, 120),
                sliver: SliverToBoxAdapter(child: _GroupSkeleton()),
              );
            }
            if (snapshot.hasError) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: _MessageState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Gruplar yüklenemedi',
                  message: 'Bağlantını kontrol edip tekrar deneyebilirsin.',
                  action: 'Tekrar dene',
                  onTap: () => _search(''),
                ),
              );
            }
            final groups = snapshot.data ?? const <GroupSummary>[];
            if (groups.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: _MessageState(
                  icon: Icons.search_off_rounded,
                  title: 'Eşleşen grup yok',
                  message: 'Başka bir grup adı, şehir veya ülke arayabilirsin.',
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
              sliver: SliverList.separated(
                itemCount: groups.length + (_nextCursor == null ? 0 : 1),
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == groups.length) {
                    return AdaptiveSecondaryButton(
                      label: _loadingMore ? 'Yükleniyor…' : 'Daha fazla göster',
                      onPressed: _loadingMore ? null : _loadMore,
                    );
                  }
                  return TweenAnimationBuilder<double>(
                    duration: Duration(milliseconds: 360 + (index * 80)),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - value)),
                        child: child,
                      ),
                    ),
                    child: _GroupCard(
                      group: groups[index],
                      onTap: () =>
                          context.push('/home/groups/${groups[index].id}'),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final user = Firebase.apps.isNotEmpty
        ? FirebaseAuth.instance.currentUser
        : null;
    if (user == null) return _content('Muhammet');
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
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<({Prayer prayer, DateTime startsAt, String timezone})?> _load() async {
    final user = Firebase.apps.isNotEmpty
        ? FirebaseAuth.instance.currentUser
        : null;
    if (user == null) {
      return (
        prayer: Prayer.dhuhr,
        startsAt: DateTime.now().add(const Duration(hours: 1, minutes: 17)),
        timezone: 'Europe/Istanbul',
      );
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
          return Semantics(
            label:
                'Sıradaki namaz ${next.prayer.label}, saat $time, $remaining',
            child: _content(
              prayerLabel: 'SIRADAKİ · ${next.prayer.label.toUpperCase()}',
              time: time,
              remaining: remaining,
            ),
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
      color: AppColors.brown,
      borderRadius: BorderRadius.circular(32),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x214F3422),
          blurRadius: 28,
          offset: Offset(0, 14),
        ),
      ],
    ),
    child: Stack(
      children: <Widget>[
        Positioned(
          right: -28,
          top: -40,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              shape: BoxShape.circle,
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

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.onTap});

  final GroupSummary group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${group.name}, ${group.memberCount} üye, yüzde ${(group.participationRate * 100).round()} katılım',
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.line, width: .7),
          ),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  GroupAvatar(group: group),
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
                          group.city == null
                              ? group.country
                              : '${group.city}, ${group.country}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.greenMist,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '%${(group.participationRate * 100).round()}',
                      style: const TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  _Stat(
                    icon: Icons.people_outline_rounded,
                    value: '${group.memberCount}/${group.capacity}',
                  ),
                  const _Dot(),
                  _Stat(
                    icon: Icons.local_fire_department_outlined,
                    value: '${group.currentStreak} gün',
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.brownSoft,
                    size: 19,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: group.participationRate,
                  minHeight: 7,
                  color: AppColors.green,
                  backgroundColor: AppColors.greenPale,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Icon(icon, size: 17, color: AppColors.muted),
      const SizedBox(width: 5),
      Text(
        value,
        style: const TextStyle(
          color: AppColors.muted,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    ],
  );
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 9),
    child: CircleAvatar(radius: 2, backgroundColor: AppColors.line),
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
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: .45, end: .9).animate(_controller),
    child: Column(
      children: List<Widget>.generate(
        2,
        (index) => Container(
          height: 152,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.line),
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
