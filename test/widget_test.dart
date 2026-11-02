import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:namaz_grubum/app/app.dart';
import 'package:namaz_grubum/core/data/demo_repository.dart';
import 'package:namaz_grubum/core/data/repository_provider.dart';
import 'package:namaz_grubum/core/services/invite_service.dart';
import 'package:namaz_grubum/core/services/adhan_prayer_time_service.dart';
import 'package:namaz_grubum/core/domain/models.dart';
import 'package:namaz_grubum/core/widgets/adaptive_page.dart';
import 'package:namaz_grubum/features/groups/presentation/create_group_screen.dart';
import 'package:namaz_grubum/features/groups/presentation/group_detail_screen.dart';
import 'package:namaz_grubum/features/groups/presentation/join_requests_screen.dart';
import 'package:namaz_grubum/features/profile/presentation/profile_screen.dart';
import 'package:namaz_grubum/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  for (final granted in <bool>[true, false]) {
    testWidgets('onboarding shows actual notification permission: $granted', (
      tester,
    ) async {
      var requests = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(
            requestNotificationPermission: () async {
              requests++;
              return granted;
            },
          ),
        ),
      );
      await tester.tap(find.text('Devam Et'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Devam Et'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bildirimlere izin ver'));
      await tester.tap(find.text('Bildirimlere izin ver'));
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(
        find.textContaining(
          granted ? 'Bildirim izni verildi.' : 'İzin kapalı.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('notification opt-out is real and does not request permission', (
    tester,
  ) async {
    var requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          requestNotificationPermission: () async {
            requests++;
            return true;
          },
        ),
      ),
    );
    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(CupertinoSwitch).first);
    await tester.tap(find.byType(CupertinoSwitch).first);
    await tester.pumpAndSettle();
    expect(find.text('Bildirimlere izin ver'), findsNothing);
    expect(requests, 0);
  });
  test('invite links accept only supported group routes', () {
    expect(
      InviteService.groupIdFromUri(
        Uri.parse('https://namaz-grubum.web.app/g/group_123'),
      ),
      'group_123',
    );
    expect(
      InviteService.groupIdFromUri(Uri.parse('namazgrubum://g/group_123')),
      'group_123',
    );
    expect(
      InviteService.groupIdFromUri(
        Uri.parse('https://example.com/g/group_123'),
      ),
      isNull,
    );
  });
  test('prayer labels are localized', () {
    expect(Prayer.fajr.label, 'Sabah');
    expect(Prayer.isha.label, 'Yatsı');
  });

  test('prayer window is open only between boundaries', () {
    final now = DateTime.now();
    final open = PrayerWindow(
      prayer: Prayer.fajr,
      startsAt: now.subtract(const Duration(minutes: 5)),
      endsAt: now.add(const Duration(minutes: 5)),
    );
    final closed = PrayerWindow(
      prayer: Prayer.fajr,
      startsAt: now.subtract(const Duration(minutes: 10)),
      endsAt: now.subtract(const Duration(minutes: 5)),
    );
    expect(open.isOpen, isTrue);
    expect(closed.isOpen, isFalse);
  });

  test('adhan schedule produces five chronological Istanbul windows', () async {
    final schedule = await AdhanPrayerTimeService().scheduleFor(
      date: DateTime(2026, 9, 25),
      latitude: 41.0082,
      longitude: 28.9784,
      madhhab: Madhhab.hanafi,
      timezone: 'Europe/Istanbul',
    );
    expect(schedule.windows, hasLength(5));
    expect(schedule.windows.first.prayer, Prayer.fajr);
    expect(schedule.windows.last.prayer, Prayer.isha);
    for (final window in schedule.windows) {
      expect(window.endsAt.isAfter(window.startsAt), isTrue);
    }
    final starts = <Prayer, (int, int)>{
      for (final window in schedule.windows)
        window.prayer: (window.startsAt.hour, window.startsAt.minute),
    };
    // Diyanet İstanbul, 25.09.2026. The calculation library can differ by
    // one or two minutes because of rounding, but must never use the roughly
    // 50-minute-later Hanafi Asr boundary for the Turkey timetable.
    void expectNear(Prayer prayer, (int, int) official) {
      final actual = starts[prayer]!;
      final actualMinutes = actual.$1 * 60 + actual.$2;
      final officialMinutes = official.$1 * 60 + official.$2;
      expect((actualMinutes - officialMinutes).abs(), lessThanOrEqualTo(2));
    }

    expectNear(Prayer.fajr, (5, 22));
    expectNear(Prayer.dhuhr, (13, 1));
    expectNear(Prayer.asr, (16, 24));
    expectNear(Prayer.maghrib, (19, 5));
    expectNear(Prayer.isha, (20, 24));
  });

  test('Üsküdar Sabah Halkası demo group has current user as owner', () async {
    final repository = DemoAppRepository();
    final group = await repository.group('sabah-sekerleri');
    final members = await repository.groupMembers('sabah-sekerleri');
    final currentUser = members.singleWhere((member) => member.isCurrentUser);

    expect(group?.name, 'Üsküdar Sabah Halkası');
    expect(group?.memberCount, members.length);
    expect(currentUser.displayName, 'Muhammet A.');
    expect(currentUser.role, GroupRole.owner);
    expect(currentUser.role.canManage, isTrue);
  });

  test('demo join requests can be resolved', () async {
    final repository = DemoAppRepository();
    final requests = await repository.pendingJoinRequests('sabah-sekerleri');
    expect(requests, hasLength(3));

    await repository.resolveJoinRequest(
      groupId: 'sabah-sekerleri',
      userId: requests.first.userId,
      approve: true,
    );

    expect(
      await repository.pendingJoinRequests('sabah-sekerleri'),
      hasLength(2),
    );
  });

  testWidgets('join requests screen shows manager actions', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: JoinRequestsScreen(groupId: 'sabah-sekerleri'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 kişi bekliyor'), findsOneWidget);
    expect(find.text('Kabul et'), findsNWidgets(3));
    expect(find.text('Reddet'), findsNWidgets(3));
  });

  testWidgets('primary action exposes its label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdaptivePrimaryButton(label: 'Kıldım', onPressed: () {}),
        ),
      ),
    );
    expect(find.text('Kıldım'), findsOneWidget);
  });

  testWidgets('photo group opens camera flow instead of button check-in', (
    tester,
  ) async {
    final repository = _PhotoFlowRepository();
    final router = GoRouter(
      initialLocation: '/home/groups/photo-flow',
      routes: <RouteBase>[
        GoRoute(
          path: '/home/groups/:groupId',
          builder: (context, state) =>
              GroupDetailScreen(groupId: state.pathParameters['groupId']!),
        ),
        GoRoute(
          path: '/home/groups/:groupId/photo-checkin',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Fotoğraf çekme ekranı')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kıldım'));
    await tester.pumpAndSettle();

    expect(find.text('Fotoğraf çekme ekranı'), findsOneWidget);
    expect(repository.buttonCheckinCount, 0);
  });

  testWidgets('future prayer cannot be confirmed', (tester) async {
    final now = DateTime.now();
    final repository = _WindowRepository(
      PrayerWindow(
        prayer: Prayer.fajr,
        startsAt: now.add(const Duration(hours: 1)),
        endsAt: now.add(const Duration(hours: 2)),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: GroupDetailScreen(groupId: 'window-test'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vakit henüz girmedi'), findsOneWidget);
    expect(find.text('Kalktım'), findsNothing);
    expect(find.text('Kıldım'), findsNothing);
  });

  testWidgets('ended prayer offers only qada completion', (tester) async {
    final now = DateTime.now();
    final repository = _WindowRepository(
      PrayerWindow(
        prayer: Prayer.fajr,
        startsAt: now.subtract(const Duration(hours: 2)),
        endsAt: now.subtract(const Duration(hours: 1)),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: GroupDetailScreen(groupId: 'window-test'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kaza kıldım'), findsOneWidget);
    expect(find.text('Kalktım'), findsNothing);
    expect(find.text('Kıldım'), findsNothing);
  });

  testWidgets('pending join request survives reopening group details', (
    tester,
  ) async {
    final repository = _PendingJoinRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: GroupDetailScreen(groupId: 'pending-join'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Katılım isteği gönderildi'), findsOneWidget);
    expect(find.text('Katılım isteği gönder'), findsNothing);
  });

  testWidgets('onboarding fits an iPhone SE with large system text', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(const NamazGrubumApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();
    expect(find.text('Bildirimler'), findsOneWidget);
    expect(tester.takeException(), isNull);

    debugDefaultTargetPlatformOverride = null;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  testWidgets('titled pages start below the iOS navigation bar', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Muhammet A.')).dy, greaterThan(60));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CreateGroupScreen())),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Grup adı')).dy, greaterThan(60));
    expect(tester.takeException(), isNull);

    debugDefaultTargetPlatformOverride = null;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class _PhotoFlowRepository extends DemoAppRepository {
  int buttonCheckinCount = 0;

  @override
  Future<GroupSummary?> group(String groupId) async => const GroupSummary(
    id: 'photo-flow',
    name: 'Fotoğraflı Grup',
    country: 'Türkiye',
    city: 'İstanbul',
    prayers: <Prayer>[Prayer.fajr],
    memberCount: 1,
    capacity: 5,
    activeMemberCount: 1,
    currentStreak: 1,
    participationRate: 0,
    verificationType: VerificationType.photo,
    joinApprovalRequired: false,
  );

  @override
  Future<List<GroupMember>> groupMembers(
    String groupId, {
    Prayer prayer = Prayer.fajr,
  }) async => const <GroupMember>[
    GroupMember(
      id: 'current-user',
      displayName: 'Test Kullanıcısı',
      location: 'İstanbul',
      status: CheckinStatus.awake,
      role: GroupRole.member,
      isCurrentUser: true,
    ),
  ];

  @override
  Future<void> completePrayer({
    required String groupId,
    required Prayer prayer,
  }) async {
    buttonCheckinCount += 1;
  }
}

class _WindowRepository extends DemoAppRepository {
  _WindowRepository(this.window);

  final PrayerWindow window;

  @override
  Future<GroupSummary?> group(String groupId) async => const GroupSummary(
    id: 'window-test',
    name: 'Vakit Test Grubu',
    country: 'Türkiye',
    city: 'İstanbul',
    prayers: <Prayer>[Prayer.fajr],
    memberCount: 1,
    capacity: 5,
    activeMemberCount: 1,
    currentStreak: 1,
    participationRate: 0,
    verificationType: VerificationType.button,
    joinApprovalRequired: false,
  );

  @override
  Future<List<GroupMember>> groupMembers(
    String groupId, {
    Prayer prayer = Prayer.fajr,
  }) async => const <GroupMember>[
    GroupMember(
      id: 'current-user',
      displayName: 'Test Kullanıcısı',
      location: 'İstanbul',
      status: CheckinStatus.pending,
      role: GroupRole.member,
      isCurrentUser: true,
    ),
  ];

  @override
  Future<Map<Prayer, PrayerWindow>> prayerWindows(Set<Prayer> prayers) async =>
      <Prayer, PrayerWindow>{Prayer.fajr: window};
}

class _PendingJoinRepository extends DemoAppRepository {
  @override
  Future<GroupSummary?> group(String groupId) async => const GroupSummary(
    id: 'pending-join',
    name: 'Bekleyen Grup',
    country: 'Türkiye',
    city: 'İstanbul',
    prayers: <Prayer>[Prayer.fajr],
    memberCount: 2,
    capacity: 5,
    activeMemberCount: 2,
    currentStreak: 1,
    participationRate: 0,
    verificationType: VerificationType.button,
    joinApprovalRequired: true,
  );

  @override
  Future<List<GroupMember>> groupMembers(
    String groupId, {
    Prayer prayer = Prayer.fajr,
  }) async => const <GroupMember>[];

  @override
  Future<bool> hasPendingJoinRequest(String groupId) async => true;
}
