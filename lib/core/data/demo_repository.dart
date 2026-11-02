import '../domain/models.dart';
import 'app_repository.dart';

class DemoAppRepository implements AppRepository {
  final Set<String> _resolvedJoinRequests = <String>{};
  static const _groups = <GroupSummary>[
    GroupSummary(
      id: 'sabah-sekerleri',
      name: 'Üsküdar Sabah Halkası',
      country: 'Türkiye',
      city: 'İstanbul',
      prayers: <Prayer>[Prayer.fajr],
      memberCount: 12,
      capacity: 30,
      activeMemberCount: 12,
      currentStreak: 6,
      participationRate: .67,
      verificationType: VerificationType.button,
      joinApprovalRequired: true,
    ),
    GroupSummary(
      id: 'sabah-gencleri',
      name: 'Kadıköy Sabah Arkadaşları',
      country: 'Türkiye',
      city: 'İstanbul',
      prayers: <Prayer>[Prayer.fajr],
      memberCount: 47,
      capacity: 50,
      activeMemberCount: 44,
      currentStreak: 12,
      participationRate: .66,
      verificationType: VerificationType.button,
      joinApprovalRequired: true,
    ),
    GroupSummary(
      id: 'ankara-bes-vakit',
      name: 'Ankara Beş Vakit',
      country: 'Türkiye',
      city: 'Ankara',
      prayers: Prayer.values,
      memberCount: 31,
      capacity: 50,
      activeMemberCount: 29,
      currentStreak: 8,
      participationRate: .83,
      verificationType: VerificationType.photo,
      joinApprovalRequired: false,
    ),
    GroupSummary(
      id: 'fajr-berlin',
      name: 'Berlin Sabah Cemaati',
      country: 'Germany',
      city: null,
      prayers: <Prayer>[Prayer.fajr, Prayer.isha],
      memberCount: 18,
      capacity: 30,
      activeMemberCount: 17,
      currentStreak: 5,
      participationRate: .78,
      verificationType: VerificationType.button,
      joinApprovalRequired: false,
    ),
    GroupSummary(
      id: 'bursa-yatsi-dostlari',
      name: 'Bursa Yatsı Dostları',
      country: 'Türkiye',
      city: 'Bursa',
      prayers: <Prayer>[Prayer.isha],
      memberCount: 24,
      capacity: 40,
      activeMemberCount: 22,
      currentStreak: 9,
      participationRate: .81,
      verificationType: VerificationType.button,
      joinApprovalRequired: false,
    ),
  ];

  @override
  Future<String> createGroup(GroupDraft draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return 'demo-created-group';
  }

  @override
  Future<GroupSummary?> group(String groupId) async {
    return _groups.where((group) => group.id == groupId).firstOrNull;
  }

  @override
  Stream<void> watchGroupUpdates(
    String groupId, {
    Prayer prayer = Prayer.fajr,
  }) => const Stream<void>.empty();

  @override
  Future<List<GroupSummary>> discoverGroups({String query = ''}) async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return _groups;
    return _groups
        .where(
          (group) => '${group.name} ${group.country} ${group.city ?? ''}'
              .toLowerCase()
              .contains(normalized),
        )
        .toList();
  }

  @override
  Future<GroupDiscoveryPage> discoverGroupPage({
    String query = '',
    String? cursor,
    int limit = 20,
  }) async {
    final matches = await discoverGroups(query: query);
    final offset = int.tryParse(cursor ?? '') ?? 0;
    final end = (offset + limit).clamp(0, matches.length);
    final page = offset >= matches.length
        ? const <GroupSummary>[]
        : matches.sublist(offset, end);
    return GroupDiscoveryPage(
      groups: page,
      nextCursor: end < matches.length ? '$end' : null,
    );
  }

  @override
  Future<List<GroupSummary>> myGroups() async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    return _groups
        .where(
          (group) =>
              group.id == 'sabah-sekerleri' ||
              group.id == 'ankara-bes-vakit' ||
              group.id == 'bursa-yatsi-dostlari',
        )
        .toList();
  }

  @override
  Future<List<GroupMember>> groupMembers(
    String groupId, {
    Prayer prayer = Prayer.fajr,
  }) async {
    if (groupId == 'sabah-sekerleri') {
      return const <GroupMember>[
        GroupMember(
          id: 'current-user',
          displayName: 'Muhammet A.',
          location: 'İstanbul',
          status: CheckinStatus.pending,
          role: GroupRole.owner,
          isCurrentUser: true,
        ),
        GroupMember(
          id: 'aykut',
          displayName: 'Aykut Demir',
          location: 'İstanbul',
          status: CheckinStatus.completed,
          role: GroupRole.moderator,
        ),
        GroupMember(
          id: 'selim',
          displayName: 'Selim Ersoy',
          location: 'Bursa',
          status: CheckinStatus.completed,
        ),
        GroupMember(
          id: 'mustafa',
          displayName: 'Mustafa Çelik',
          location: 'İstanbul',
          status: CheckinStatus.completed,
        ),
        GroupMember(
          id: 'emir',
          displayName: 'Emir Hasan',
          location: 'Ankara',
          status: CheckinStatus.completed,
        ),
        GroupMember(
          id: 'bilal',
          displayName: 'Bilal Kaya',
          location: 'Kocaeli',
          status: CheckinStatus.completed,
        ),
        GroupMember(
          id: 'hamza',
          displayName: 'Hamza Rahman',
          location: 'İstanbul',
          status: CheckinStatus.completed,
        ),
        GroupMember(
          id: 'mert',
          displayName: 'Mert Taş',
          location: 'Tekirdağ',
          status: CheckinStatus.completed,
        ),
        GroupMember(
          id: 'yunus',
          displayName: 'Yunus Şahin',
          location: 'İstanbul',
          status: CheckinStatus.awake,
        ),
        GroupMember(
          id: 'ibrahim',
          displayName: 'İbrahim Nur',
          location: 'Sakarya',
          status: CheckinStatus.awake,
        ),
        GroupMember(
          id: 'kaan',
          displayName: 'Kaan Yıldız',
          location: 'İstanbul',
          status: CheckinStatus.pending,
        ),
        GroupMember(
          id: 'furkan',
          displayName: 'Furkan Bulut',
          location: 'İstanbul',
          status: CheckinStatus.pending,
        ),
      ];
    }
    return const <GroupMember>[
      GroupMember(
        id: 'current-user',
        displayName: 'Muhammet A.',
        location: 'İstanbul',
        status: CheckinStatus.completed,
        isCurrentUser: true,
      ),
      GroupMember(
        id: '1',
        displayName: 'Ahmet Arslan',
        location: 'Ankara',
        status: CheckinStatus.completed,
      ),
      GroupMember(
        id: '2',
        displayName: 'Mehmet Kaya',
        location: 'İstanbul',
        status: CheckinStatus.awake,
      ),
      GroupMember(
        id: '3',
        displayName: 'Yusuf Tunç',
        location: 'Ankara',
        status: CheckinStatus.pending,
      ),
      GroupMember(
        id: '4',
        displayName: 'Ömer Bilgin',
        location: 'Germany',
        status: CheckinStatus.completedWithPhoto,
      ),
      GroupMember(
        id: '5',
        displayName: 'Kerem Demir',
        location: 'Bursa',
        status: CheckinStatus.pending,
      ),
    ];
  }

  @override
  Future<List<RankingEntry>> rankings({required int days}) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    return const <RankingEntry>[
      RankingEntry(
        groupName: 'Üsküdar Sabah Halkası',
        score: .946,
        activeMembers: 12,
      ),
      RankingEntry(
        groupName: 'Kadıköy Sabah Arkadaşları',
        score: .918,
        activeMembers: 44,
      ),
      RankingEntry(
        groupName: 'Ankara Beş Vakit',
        score: .887,
        activeMembers: 29,
      ),
      RankingEntry(
        groupName: 'Bursa Yatsı Dostları',
        score: .854,
        activeMembers: 22,
      ),
      RankingEntry(
        groupName: 'Berlin Sabah Cemaati',
        score: .821,
        activeMembers: 17,
      ),
    ];
  }

  @override
  Future<void> completePrayer({
    required String groupId,
    required Prayer prayer,
  }) => Future<void>.delayed(const Duration(milliseconds: 350));

  @override
  Future<void> completeQada({
    required String groupId,
    required Prayer prayer,
  }) => Future<void>.delayed(const Duration(milliseconds: 350));

  @override
  Future<void> markAwake({required String groupId, required Prayer prayer}) =>
      Future<void>.delayed(const Duration(milliseconds: 280));

  @override
  Future<void> wakeMember({
    required String groupId,
    required String memberId,
    Prayer prayer = Prayer.fajr,
  }) => Future<void>.delayed(const Duration(milliseconds: 280));

  @override
  Future<bool> joinGroup(String groupId) async {
    await Future<void>.delayed(const Duration(milliseconds: 360));
    return groupId == 'sabah-gencleri';
  }

  @override
  Future<bool> hasPendingJoinRequest(String groupId) async => false;

  @override
  Future<Map<Prayer, PrayerWindow>> prayerWindows(Set<Prayer> prayers) async {
    final now = DateTime.now();
    return <Prayer, PrayerWindow>{
      for (final prayer in prayers)
        prayer: PrayerWindow(
          prayer: prayer,
          startsAt: now.subtract(const Duration(minutes: 30)),
          endsAt: now.add(const Duration(minutes: 30)),
        ),
    };
  }

  @override
  Future<void> leaveGroup(String groupId) =>
      Future<void>.delayed(const Duration(milliseconds: 260));

  @override
  Future<void> transferGroupOwnership({
    required String groupId,
    required String targetUserId,
  }) => Future<void>.delayed(const Duration(milliseconds: 320));

  @override
  Future<void> setMemberRole({
    required String groupId,
    required String targetUserId,
    required GroupRole role,
  }) => Future<void>.delayed(const Duration(milliseconds: 300));

  @override
  Future<void> removeGroupMember({
    required String groupId,
    required String targetUserId,
  }) => Future<void>.delayed(const Duration(milliseconds: 300));

  @override
  Future<void> archiveGroup(String groupId) =>
      Future<void>.delayed(const Duration(milliseconds: 350));

  @override
  Future<void> updateGroup({
    required String groupId,
    required String name,
    required Set<Prayer> prayers,
    required bool joinApprovalRequired,
  }) => Future<void>.delayed(const Duration(milliseconds: 360));

  @override
  Future<List<GroupJoinRequest>> pendingJoinRequests(String groupId) async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (groupId != 'sabah-sekerleri') return const <GroupJoinRequest>[];
    final now = DateTime.now();
    return <GroupJoinRequest>[
          GroupJoinRequest(
            userId: 'request-1',
            displayName: 'Zeynep Koç',
            location: 'İstanbul',
            createdAt: now.subtract(const Duration(minutes: 18)),
          ),
          GroupJoinRequest(
            userId: 'request-2',
            displayName: 'Emre Tekin',
            location: 'Bursa',
            createdAt: now.subtract(const Duration(hours: 2)),
          ),
          GroupJoinRequest(
            userId: 'request-3',
            displayName: 'Yusuf Aksoy',
            location: 'Kocaeli',
            createdAt: now.subtract(const Duration(days: 1)),
          ),
        ]
        .where((request) => !_resolvedJoinRequests.contains(request.userId))
        .toList();
  }

  @override
  Future<void> resolveJoinRequest({
    required String groupId,
    required String userId,
    required bool approve,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    _resolvedJoinRequests.add(userId);
  }

  @override
  Future<void> suspendGroupMember({
    required String groupId,
    required String targetUserId,
    required int durationDays,
  }) => Future<void>.delayed(const Duration(milliseconds: 260));

  @override
  Future<void> blockUser(String targetUserId) =>
      Future<void>.delayed(const Duration(milliseconds: 180));

  @override
  Future<void> reportUser({required String userId, required String reason}) =>
      Future<void>.delayed(const Duration(milliseconds: 180));

  @override
  Future<void> reportGroup({required String groupId, required String reason}) =>
      Future<void>.delayed(const Duration(milliseconds: 180));

  @override
  Future<void> sendAdminReminder({
    required String groupId,
    required Prayer prayer,
  }) => Future<void>.delayed(const Duration(milliseconds: 320));

  @override
  Future<List<PrayerPhoto>> prayerPhotos({
    required String groupId,
    required Prayer prayer,
  }) async => const <PrayerPhoto>[];

  @override
  Future<void> reportPhoto({required String photoId, required String reason}) =>
      Future<void>.delayed(const Duration(milliseconds: 260));
}
