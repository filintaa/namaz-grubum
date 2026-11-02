abstract interface class AnalyticsService {
  Future<void> track(
    String event, {
    Map<String, Object?> parameters = const {},
  });
}

abstract final class AnalyticsEvents {
  static const onboardingCompleted = 'onboarding_completed';
  static const groupViewed = 'group_viewed';
  static const groupJoinRequested = 'group_join_requested';
  static const groupJoined = 'group_joined';
  static const groupCreated = 'group_created';
  static const inviteShared = 'invite_shared';
  static const inviteOpened = 'invite_opened';
  static const alarmTriggered = 'alarm_triggered';
  static const awakeClicked = 'awake_clicked';
  static const prayerCompleted = 'prayer_completed';
  static const photoCheckinCompleted = 'photo_checkin_completed';
  static const wakeNudgeSent = 'wake_nudge_sent';
  static const adminReminderSent = 'admin_reminder_sent';
  static const qadaCompleted = 'qada_completed';
  static const photoReported = 'photo_reported';
  static const groupLeft = 'group_left';
}
