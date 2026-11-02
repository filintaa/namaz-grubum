enum Gender { female, male }

enum Madhhab { hanafi, shafii }

enum Prayer { fajr, dhuhr, asr, maghrib, isha }

extension PrayerLabel on Prayer {
  String get label => switch (this) {
    Prayer.fajr => 'Sabah',
    Prayer.dhuhr => 'Öğle',
    Prayer.asr => 'İkindi',
    Prayer.maghrib => 'Akşam',
    Prayer.isha => 'Yatsı',
  };
}

enum VerificationType { button, photo }

enum GroupRole { owner, moderator, member }

extension GroupRoleLabel on GroupRole {
  String get label => switch (this) {
    GroupRole.owner => 'Sahip',
    GroupRole.moderator => 'Yönetici',
    GroupRole.member => 'Üye',
  };

  bool get canManage => this == GroupRole.owner || this == GroupRole.moderator;
}

enum CheckinStatus {
  pending,
  awake,
  completed,
  completedWithPhoto,
  missed,
  qadaCompleted,
}

extension CheckinStatusLabel on CheckinStatus {
  String get label => switch (this) {
    CheckinStatus.pending => 'Henüz kalkmadı',
    CheckinStatus.awake => 'Kalktı',
    CheckinStatus.completed => 'Kıldı',
    CheckinStatus.completedWithPhoto => 'Fotoğrafla tamamladı',
    CheckinStatus.missed => 'Vakti kaçırdı',
    CheckinStatus.qadaCompleted => 'Kaza kıldı',
  };
}

class PrayerWindow {
  const PrayerWindow({
    required this.prayer,
    required this.startsAt,
    required this.endsAt,
  });

  final Prayer prayer;
  final DateTime startsAt;
  final DateTime endsAt;

  bool get isOpen {
    final now = DateTime.now();
    return !now.isBefore(startsAt) && now.isBefore(endsAt);
  }

  bool get isUpcoming => DateTime.now().isBefore(startsAt);

  bool get hasEnded => !DateTime.now().isBefore(endsAt);
}

class GroupSummary {
  const GroupSummary({
    required this.id,
    required this.name,
    required this.country,
    required this.city,
    required this.prayers,
    required this.memberCount,
    required this.capacity,
    required this.activeMemberCount,
    required this.currentStreak,
    required this.participationRate,
    required this.verificationType,
    required this.joinApprovalRequired,
    this.logoEmoji,
    this.logoObjectKey,
  });

  final String id;
  final String name;
  final String country;
  final String? city;
  final List<Prayer> prayers;
  final int memberCount;
  final int capacity;
  final int activeMemberCount;
  final int currentStreak;
  final double participationRate;
  final VerificationType verificationType;
  final bool joinApprovalRequired;
  final String? logoEmoji;
  final String? logoObjectKey;
}

class GroupDiscoveryPage {
  const GroupDiscoveryPage({required this.groups, this.nextCursor});

  final List<GroupSummary> groups;
  final String? nextCursor;
}

class GroupDraft {
  const GroupDraft({
    required this.name,
    required this.countryCode,
    required this.city,
    required this.prayers,
    required this.verificationType,
    required this.joinApprovalRequired,
    this.logoEmoji,
  });

  final String name;
  final String countryCode;
  final String? city;
  final Set<Prayer> prayers;
  final VerificationType verificationType;
  final bool joinApprovalRequired;
  final String? logoEmoji;
}

class GroupMember {
  const GroupMember({
    required this.id,
    required this.displayName,
    required this.location,
    required this.status,
    this.role = GroupRole.member,
    this.isCurrentUser = false,
  });

  final String id;
  final String displayName;
  final String location;
  final CheckinStatus status;
  final GroupRole role;
  final bool isCurrentUser;
}

class RankingEntry {
  const RankingEntry({
    required this.groupName,
    required this.score,
    required this.activeMembers,
  });

  final String groupName;
  final double score;
  final int activeMembers;
}

class GroupJoinRequest {
  const GroupJoinRequest({
    required this.userId,
    required this.displayName,
    required this.location,
    required this.createdAt,
  });

  final String userId;
  final String displayName;
  final String location;
  final DateTime createdAt;
}

class PrayerPhoto {
  const PrayerPhoto({
    required this.id,
    required this.userId,
    required this.objectKey,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String userId;
  final String objectKey;
  final DateTime createdAt;
  final DateTime expiresAt;
}
