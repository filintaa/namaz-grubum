import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/models.dart';
import '../services/offline_action_queue.dart';
import '../services/alarm_coordinator.dart';
import 'package:flutter/foundation.dart';
import 'app_repository.dart';

class FirebaseAppRepository implements AppRepository {
  FirebaseAppRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1'),
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;
  static const _uuid = Uuid();

  String get _userId {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Authentication is required.');
    return user.uid;
  }

  @override
  Future<String> createGroup(GroupDraft draft) async {
    final result = await _functions
        .httpsCallable('createGroup')
        .call(<String, Object?>{
          'name': draft.name,
          'countryCode': draft.countryCode,
          'city': draft.city,
          'prayers': draft.prayers.map((prayer) => prayer.name).toList(),
          'verificationType': draft.verificationType.name,
          'joinApprovalRequired': draft.joinApprovalRequired,
          'logoEmoji': draft.logoEmoji,
          'idempotencyKey': _uuid.v4(),
        });
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['groupId'] as String;
  }

  @override
  Future<GroupSummary?> group(String groupId) async {
    final document = await _firestore.doc('groups/$groupId').get();
    if (!document.exists) return null;
    return _groupFromDocument(document);
  }

  @override
  Stream<void> watchGroupUpdates(
    String groupId, {
    Prayer prayer = Prayer.fajr,
  }) => Stream.fromFuture(_dateKeyFor(prayer)).asyncExpand(
    (dateKey) => _watchGroupUpdatesForDate(groupId, prayer, dateKey),
  );

  Stream<void> _watchGroupUpdatesForDate(
    String groupId,
    Prayer prayer,
    String dateKey,
  ) {
    late final StreamController<void> controller;
    final subscriptions = <StreamSubscription<Object?>>[];
    controller = StreamController<void>(
      onListen: () {
        void forward(Object? _) => controller.add(null);
        subscriptions.add(
          _firestore.doc('groups/$groupId').snapshots().listen(forward),
        );
        subscriptions.add(
          _firestore
              .collection('groups/$groupId/members')
              .where('status', isEqualTo: 'active')
              .snapshots()
              .listen(forward),
        );
        subscriptions.add(
          _firestore
              .collection('groups/$groupId/prayerDays/$dateKey/checkins')
              .where('prayer', isEqualTo: prayer.name)
              .snapshots()
              .listen(forward),
        );
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  @override
  Future<List<GroupSummary>> discoverGroups({String query = ''}) async {
    return (await discoverGroupPage(query: query)).groups;
  }

  @override
  Future<GroupDiscoveryPage> discoverGroupPage({
    String query = '',
    String? cursor,
    int limit = 20,
  }) async {
    final result = await _functions.httpsCallable('discoverGroups').call(
      <String, Object?>{
        'query': query,
        'cursor': cursor,
        'limit': limit.clamp(1, 30),
      },
    );
    final data = Map<String, dynamic>.from(result.data as Map);
    final groups = (data['groups'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => _groupFromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
    return GroupDiscoveryPage(
      groups: groups,
      nextCursor: data['nextCursor'] as String?,
    );
  }

  @override
  Future<List<GroupSummary>> myGroups() async {
    final memberships = await _firestore
        .collection('users/$_userId/groupMemberships')
        .where('status', isEqualTo: 'active')
        .limit(3)
        .get();
    if (memberships.docs.isEmpty) return const <GroupSummary>[];
    final documents = await Future.wait(
      memberships.docs.map((membership) {
        final groupId =
            membership.data()['groupId'] as String? ?? membership.id;
        return _firestore.doc('groups/$groupId').get();
      }),
    );
    return documents
        .where(
          (document) =>
              document.exists && document.data()?['status'] == 'active',
        )
        .map(_groupFromDocument)
        .toList();
  }

  GroupSummary _groupFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) {
      throw StateError('Group document ${document.id} has no data.');
    }
    final prayerValues =
        (data['prayers'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<String>()
            .map(
              (value) =>
                  Prayer.values.where((item) => item.name == value).firstOrNull,
            )
            .nonNulls
            .toList();
    return GroupSummary(
      id: document.id,
      name: data['name'] as String? ?? 'İsimsiz grup',
      country: data['countryCode'] as String? ?? '',
      city: data['city'] as String?,
      prayers: prayerValues,
      memberCount: (data['memberCount'] as num?)?.toInt() ?? 0,
      capacity: (data['capacity'] as num?)?.toInt() ?? 50,
      activeMemberCount: (data['activeMemberCount'] as num?)?.toInt() ?? 0,
      currentStreak: (data['currentStreak'] as num?)?.toInt() ?? 0,
      participationRate: (data['participationRate'] as num?)?.toDouble() ?? 0,
      verificationType: data['verificationType'] == 'photo'
          ? VerificationType.photo
          : VerificationType.button,
      joinApprovalRequired: data['joinApprovalRequired'] as bool? ?? false,
      logoEmoji: data['logoEmoji'] as String?,
      logoObjectKey: data['logoObjectKey'] as String?,
    );
  }

  GroupSummary _groupFromMap(Map<String, dynamic> data) {
    final prayerValues = (data['prayers'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .map(
          (value) =>
              Prayer.values.where((item) => item.name == value).firstOrNull,
        )
        .nonNulls
        .toList();
    return GroupSummary(
      id: data['id'] as String,
      name: data['name'] as String? ?? 'İsimsiz grup',
      country: data['countryCode'] as String? ?? '',
      city: data['city'] as String?,
      prayers: prayerValues,
      memberCount: (data['memberCount'] as num?)?.toInt() ?? 0,
      capacity: (data['capacity'] as num?)?.toInt() ?? 50,
      activeMemberCount: (data['activeMemberCount'] as num?)?.toInt() ?? 0,
      currentStreak: (data['currentStreak'] as num?)?.toInt() ?? 0,
      participationRate: (data['participationRate'] as num?)?.toDouble() ?? 0,
      verificationType: data['verificationType'] == 'photo'
          ? VerificationType.photo
          : VerificationType.button,
      joinApprovalRequired: data['joinApprovalRequired'] as bool? ?? false,
      logoEmoji: data['logoEmoji'] as String?,
      logoObjectKey: data['logoObjectKey'] as String?,
    );
  }

  @override
  Future<List<GroupMember>> groupMembers(
    String groupId, {
    Prayer prayer = Prayer.fajr,
  }) async {
    final dateKey = await _dateKeyFor(prayer);
    late final QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _firestore
          .collection('groups/$groupId/members')
          .where('status', isEqualTo: 'active')
          .limit(100)
          .get();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') return const <GroupMember>[];
      rethrow;
    }
    final checkins = await _firestore
        .collection('groups/$groupId/prayerDays/$dateKey/checkins')
        .where('prayer', isEqualTo: prayer.name)
        .get();
    final statusByUser = <String, String>{
      for (final document in checkins.docs)
        if (document.data()['userId'] is String)
          document.data()['userId'] as String:
              document.data()['status'] as String? ?? 'pending',
    };
    return snapshot.docs.map((document) {
      final data = document.data();
      final statusName = statusByUser[document.id] ?? 'pending';
      final roleName = data['role'] as String? ?? 'member';
      return GroupMember(
        id: document.id,
        displayName: data['displayName'] as String? ?? 'Üye',
        location:
            data['city'] as String? ?? data['countryCode'] as String? ?? '',
        status: switch (statusName) {
          'awake' => CheckinStatus.awake,
          'completed' => CheckinStatus.completed,
          'completed_with_photo' => CheckinStatus.completedWithPhoto,
          'missed' => CheckinStatus.missed,
          'qada_completed' => CheckinStatus.qadaCompleted,
          _ => CheckinStatus.pending,
        },
        role: switch (roleName) {
          'owner' => GroupRole.owner,
          'moderator' => GroupRole.moderator,
          _ => GroupRole.member,
        },
        isCurrentUser: document.id == _userId,
      );
    }).toList();
  }

  @override
  Future<List<RankingEntry>> rankings({required int days}) async {
    final snapshot = await _firestore
        .collection('leaderboards')
        .where('periodDays', isEqualTo: days)
        .orderBy('score', descending: true)
        .limit(50)
        .get();
    return snapshot.docs.map((document) {
      final data = document.data();
      return RankingEntry(
        groupName: data['groupName'] as String? ?? 'Grup',
        score: (data['score'] as num?)?.toDouble() ?? 0,
        activeMembers: (data['activeMemberCount'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  Future<void> _record(String action, String groupId, Prayer prayer) async {
    final dateKey = await _dateKeyFor(prayer);
    final payload = <String, Object>{
      'groupId': groupId,
      'prayer': prayer.name,
      'dateKey': dateKey,
      'action': action,
      'idempotencyKey': _uuid.v4(),
    };
    try {
      await _functions.httpsCallable('recordCheckin').call(payload);
      if (action == 'complete') {
        try {
          await AlarmCoordinator.instance.markPrayerCompleted(
            prayer: prayer,
            dateKey: dateKey,
          );
        } catch (error) {
          debugPrint('Completed prayer alarm cancellation failed: $error');
        }
      }
      await OfflineActionQueue.instance.flush();
    } on FirebaseFunctionsException catch (error) {
      if (!OfflineActionQueue.instance.isNetworkError(error)) rethrow;
      await OfflineActionQueue.instance.enqueueRecordCheckin(payload);
    }
  }

  Future<String> _dateKeyFor(Prayer prayer) async {
    final profile = await _firestore.doc('users/$_userId').get();
    final timezoneName =
        profile.data()?['timezone'] as String? ?? 'Europe/Istanbul';
    tz_data.initializeTimeZones();
    final location = tz.getLocation(timezoneName);
    final now = tz.TZDateTime.now(location);
    String key(DateTime date) =>
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    if (prayer == Prayer.isha) {
      final previousKey = key(now.subtract(const Duration(days: 1)));
      final previous = await _firestore
          .doc('users/$_userId/prayerDays/$previousKey')
          .get();
      final window =
          (previous.data()?['windows'] as Map<String, dynamic>?)?['isha']
              as Map<String, dynamic>?;
      final startsAt = window?['startsAt'] as Timestamp?;
      final endsAt = window?['endsAt'] as Timestamp?;
      if (startsAt != null &&
          endsAt != null &&
          !DateTime.now().isBefore(startsAt.toDate()) &&
          DateTime.now().isBefore(endsAt.toDate())) {
        return previousKey;
      }
    }
    return key(now);
  }

  @override
  Future<Map<Prayer, PrayerWindow>> prayerWindows(Set<Prayer> prayers) async {
    if (prayers.isEmpty) return const <Prayer, PrayerWindow>{};
    final profile = await _firestore.doc('users/$_userId').get();
    final timezoneName =
        profile.data()?['timezone'] as String? ?? 'Europe/Istanbul';
    tz_data.initializeTimeZones();
    final location = tz.getLocation(timezoneName);
    final now = tz.TZDateTime.now(location);
    String key(DateTime date) =>
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    final todayFuture = _firestore
        .doc('users/$_userId/prayerDays/${key(now)}')
        .get();
    final previousFuture = prayers.contains(Prayer.isha)
        ? _firestore
              .doc(
                'users/$_userId/prayerDays/'
                '${key(now.subtract(const Duration(days: 1)))}',
              )
              .get()
        : null;
    final today = await todayFuture;
    final previous = await previousFuture;
    final todayWindows = today.data()?['windows'] as Map<String, dynamic>?;
    final previousWindows =
        previous?.data()?['windows'] as Map<String, dynamic>?;

    PrayerWindow? parse(Prayer prayer, Map<String, dynamic>? windows) {
      final raw = windows?[prayer.name] as Map<String, dynamic>?;
      final startsAt = raw?['startsAt'] as Timestamp?;
      final endsAt = raw?['endsAt'] as Timestamp?;
      if (startsAt == null || endsAt == null) return null;
      return PrayerWindow(
        prayer: prayer,
        startsAt: startsAt.toDate(),
        endsAt: endsAt.toDate(),
      );
    }

    final result = <Prayer, PrayerWindow>{};
    for (final prayer in prayers) {
      if (prayer == Prayer.isha) {
        final previousIsha = parse(prayer, previousWindows);
        if (previousIsha?.isOpen ?? false) {
          result[prayer] = previousIsha!;
          continue;
        }
      }
      final window = parse(prayer, todayWindows);
      if (window != null) result[prayer] = window;
    }
    return result;
  }

  @override
  Future<bool> hasPendingJoinRequest(String groupId) async {
    final request = await _firestore
        .doc('groups/$groupId/joinRequests/$_userId')
        .get();
    return request.data()?['status'] == 'pending';
  }

  @override
  Future<void> markAwake({required String groupId, required Prayer prayer}) =>
      _record('awake', groupId, prayer);

  @override
  Future<void> completePrayer({
    required String groupId,
    required Prayer prayer,
  }) => _record('complete', groupId, prayer);

  @override
  Future<void> completeQada({
    required String groupId,
    required Prayer prayer,
  }) => _record('qada', groupId, prayer);

  @override
  Future<void> wakeMember({
    required String groupId,
    required String memberId,
    Prayer prayer = Prayer.fajr,
  }) async {
    final dateKey = await _dateKeyFor(prayer);
    await _functions.httpsCallable('wakeMember').call(<String, Object>{
      'groupId': groupId,
      'targetUserId': memberId,
      'prayer': prayer.name,
      'dateKey': dateKey,
    });
  }

  @override
  Future<bool> joinGroup(String groupId) async {
    final result = await _functions.httpsCallable('joinGroup').call(
      <String, Object>{'groupId': groupId, 'idempotencyKey': _uuid.v4()},
    );
    return Map<String, dynamic>.from(result.data as Map)['approved'] as bool? ??
        false;
  }

  @override
  Future<void> leaveGroup(String groupId) => _functions
      .httpsCallable('leaveGroup')
      .call(<String, Object>{'groupId': groupId});

  @override
  Future<void> transferGroupOwnership({
    required String groupId,
    required String targetUserId,
  }) => _functions.httpsCallable('transferGroupOwnership').call(
    <String, Object>{'groupId': groupId, 'targetUserId': targetUserId},
  );

  @override
  Future<void> setMemberRole({
    required String groupId,
    required String targetUserId,
    required GroupRole role,
  }) => _functions.httpsCallable('setMemberRole').call(<String, Object>{
    'groupId': groupId,
    'targetUserId': targetUserId,
    'role': role.name,
  });

  @override
  Future<void> removeGroupMember({
    required String groupId,
    required String targetUserId,
  }) => _functions.httpsCallable('removeGroupMember').call(<String, Object>{
    'groupId': groupId,
    'targetUserId': targetUserId,
  });

  @override
  Future<void> suspendGroupMember({
    required String groupId,
    required String targetUserId,
    required int durationDays,
  }) => _functions.httpsCallable('suspendGroupMember').call(<String, Object>{
    'groupId': groupId,
    'targetUserId': targetUserId,
    'durationDays': durationDays,
  });

  @override
  Future<void> blockUser(String targetUserId) => _functions
      .httpsCallable('blockUser')
      .call(<String, Object>{'targetUserId': targetUserId});

  @override
  Future<void> reportUser({required String userId, required String reason}) =>
      _functions.httpsCallable('reportContent').call(<String, Object>{
        'targetType': 'user',
        'targetId': userId,
        'reason': reason,
      });

  @override
  Future<void> reportGroup({required String groupId, required String reason}) =>
      _functions.httpsCallable('reportContent').call(<String, Object>{
        'targetType': 'group',
        'targetId': groupId,
        'reason': reason,
      });

  @override
  Future<void> archiveGroup(String groupId) => _functions
      .httpsCallable('archiveGroup')
      .call(<String, Object>{'groupId': groupId});

  @override
  Future<void> updateGroup({
    required String groupId,
    required String name,
    required Set<Prayer> prayers,
    required bool joinApprovalRequired,
  }) => _functions.httpsCallable('updateGroup').call(<String, Object>{
    'groupId': groupId,
    'name': name,
    'prayers': prayers.map((prayer) => prayer.name).toList(),
    'joinApprovalRequired': joinApprovalRequired,
  });

  @override
  Future<List<GroupJoinRequest>> pendingJoinRequests(String groupId) async {
    final snapshot = await _firestore
        .collection('groups/$groupId/joinRequests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt')
        .limit(50)
        .get();
    return snapshot.docs.map((document) {
      final data = document.data();
      return GroupJoinRequest(
        userId: data['userId'] as String? ?? document.id,
        displayName: data['displayName'] as String? ?? 'Üye',
        location:
            data['city'] as String? ?? data['countryCode'] as String? ?? '',
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    }).toList();
  }

  @override
  Future<void> resolveJoinRequest({
    required String groupId,
    required String userId,
    required bool approve,
  }) => _functions.httpsCallable('resolveJoinRequest').call(<String, Object>{
    'groupId': groupId,
    'targetUserId': userId,
    'approve': approve,
  });

  @override
  Future<void> sendAdminReminder({
    required String groupId,
    required Prayer prayer,
  }) async {
    final dateKey = await _dateKeyFor(prayer);
    await _functions.httpsCallable('sendAdminReminder').call(<String, Object>{
      'groupId': groupId,
      'prayer': prayer.name,
      'dateKey': dateKey,
    });
  }

  @override
  Future<List<PrayerPhoto>> prayerPhotos({
    required String groupId,
    required Prayer prayer,
  }) async {
    final dateKey = await _dateKeyFor(prayer);
    final snapshot = await _firestore
        .collection('photos')
        .where('groupId', isEqualTo: groupId)
        .where('dateKey', isEqualTo: dateKey)
        .where('prayer', isEqualTo: prayer.name)
        .where('status', isEqualTo: 'visible')
        .limit(50)
        .get();
    return snapshot.docs
        .map((document) {
          final data = document.data();
          return PrayerPhoto(
            id: document.id,
            userId: data['userId'] as String? ?? '',
            objectKey: data['objectKey'] as String? ?? '',
            createdAt:
                (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            expiresAt:
                (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          );
        })
        .where((photo) => photo.objectKey.isNotEmpty)
        .toList();
  }

  @override
  Future<void> reportPhoto({required String photoId, required String reason}) =>
      _functions.httpsCallable('reportContent').call(<String, Object>{
        'targetType': 'photo',
        'targetId': photoId,
        'reason': reason,
      });
}
