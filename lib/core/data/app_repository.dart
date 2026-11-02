import '../domain/models.dart';

abstract interface class AppRepository {
  Future<String> createGroup(GroupDraft draft);
  Future<GroupSummary?> group(String groupId);
  Stream<void> watchGroupUpdates(String groupId, {Prayer prayer = Prayer.fajr});
  Future<List<GroupSummary>> discoverGroups({String query = ''});
  Future<GroupDiscoveryPage> discoverGroupPage({
    String query = '',
    String? cursor,
    int limit = 20,
  });
  Future<List<GroupSummary>> myGroups();
  Future<List<GroupMember>> groupMembers(
    String groupId, {
    Prayer prayer = Prayer.fajr,
  });
  Future<Map<Prayer, PrayerWindow>> prayerWindows(Set<Prayer> prayers);
  Future<bool> hasPendingJoinRequest(String groupId);
  Future<List<RankingEntry>> rankings({required int days});
  Future<void> markAwake({required String groupId, required Prayer prayer});
  Future<void> completePrayer({
    required String groupId,
    required Prayer prayer,
  });
  Future<void> completeQada({required String groupId, required Prayer prayer});
  Future<void> wakeMember({
    required String groupId,
    required String memberId,
    Prayer prayer = Prayer.fajr,
  });
  Future<bool> joinGroup(String groupId);
  Future<void> leaveGroup(String groupId);
  Future<void> transferGroupOwnership({
    required String groupId,
    required String targetUserId,
  });
  Future<void> setMemberRole({
    required String groupId,
    required String targetUserId,
    required GroupRole role,
  });
  Future<void> removeGroupMember({
    required String groupId,
    required String targetUserId,
  });
  Future<void> suspendGroupMember({
    required String groupId,
    required String targetUserId,
    required int durationDays,
  });
  Future<void> blockUser(String targetUserId);
  Future<void> reportUser({required String userId, required String reason});
  Future<void> reportGroup({required String groupId, required String reason});
  Future<void> archiveGroup(String groupId);
  Future<void> updateGroup({
    required String groupId,
    required String name,
    required Set<Prayer> prayers,
    required bool joinApprovalRequired,
  });
  Future<List<GroupJoinRequest>> pendingJoinRequests(String groupId);
  Future<void> resolveJoinRequest({
    required String groupId,
    required String userId,
    required bool approve,
  });
  Future<void> sendAdminReminder({
    required String groupId,
    required Prayer prayer,
  });
  Future<List<PrayerPhoto>> prayerPhotos({
    required String groupId,
    required Prayer prayer,
  });
  Future<void> reportPhoto({required String photoId, required String reason});
}
