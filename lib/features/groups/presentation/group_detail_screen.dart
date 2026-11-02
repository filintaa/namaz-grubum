import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/repository_provider.dart';
import '../../../core/domain/models.dart';
import '../../../core/services/invite_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive_page.dart';
import '../../../core/widgets/group_avatar.dart';
import 'prayer_photo_strip.dart';

typedef _GroupDetailData = ({
  GroupSummary? group,
  List<GroupMember> members,
  Map<Prayer, PrayerWindow> windows,
  bool joinRequested,
});

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  late Future<_GroupDetailData> _groupData;
  CheckinStatus _myStatus = CheckinStatus.pending;
  Prayer _selectedPrayer = Prayer.fajr;
  String? _busyMember;
  bool _reminderSent = false;
  bool _joining = false;
  bool _joinRequested = false;
  StreamSubscription<void>? _refreshSubscription;
  Timer? _refreshDebounce;

  @override
  void initState() {
    super.initState();
    _groupData = _loadGroup();
    _watchUpdates();
  }

  void _watchUpdates() {
    _refreshSubscription?.cancel();
    _refreshSubscription = ref
        .read(appRepositoryProvider)
        .watchGroupUpdates(widget.groupId, prayer: _selectedPrayer)
        .listen((_) {
          _refreshDebounce?.cancel();
          _refreshDebounce = Timer(const Duration(milliseconds: 250), () {
            if (mounted) setState(() => _groupData = _loadGroup());
          });
        });
  }

  @override
  void dispose() {
    _refreshSubscription?.cancel();
    _refreshDebounce?.cancel();
    super.dispose();
  }

  Future<_GroupDetailData> _loadGroup() async {
    final repository = ref.read(appRepositoryProvider);
    final group = await repository.group(widget.groupId);
    if (group != null &&
        group.prayers.isNotEmpty &&
        !group.prayers.contains(_selectedPrayer)) {
      _selectedPrayer = group.prayers.first;
    }
    final membersFuture = repository.groupMembers(
      widget.groupId,
      prayer: _selectedPrayer,
    );
    final windowsFuture = repository.prayerWindows(
      group?.prayers.toSet() ?? const <Prayer>{},
    );
    final joinRequestedFuture = repository.hasPendingJoinRequest(
      widget.groupId,
    );
    final members = await membersFuture;
    final windows = await windowsFuture;
    final joinRequested = await joinRequestedFuture;
    final currentUser = members
        .where((member) => member.isCurrentUser)
        .firstOrNull;
    if (currentUser != null) {
      _myStatus = currentUser.status;
      _joinRequested = false;
    } else {
      _joinRequested = joinRequested;
    }
    return (
      group: group,
      members: members,
      windows: windows,
      joinRequested: joinRequested,
    );
  }

  void _selectPrayer(Prayer prayer) {
    if (prayer == _selectedPrayer) return;
    setState(() {
      _selectedPrayer = prayer;
      _myStatus = CheckinStatus.pending;
      _reminderSent = false;
      _groupData = _loadGroup();
    });
    _watchUpdates();
  }

  Future<void> _markAwake() async {
    setState(() => _myStatus = CheckinStatus.awake);
    try {
      await ref
          .read(appRepositoryProvider)
          .markAwake(groupId: widget.groupId, prayer: _selectedPrayer);
      if (mounted) await _showMessage('Kalktın olarak işaretlendi.');
    } catch (_) {
      if (mounted) setState(() => _myStatus = CheckinStatus.pending);
    }
  }

  Future<void> _complete(GroupSummary group) async {
    if (group.verificationType == VerificationType.photo) {
      await _openPhotoCheckin(group.id);
      return;
    }

    final previous = _myStatus;
    setState(() => _myStatus = CheckinStatus.completed);
    try {
      await ref
          .read(appRepositoryProvider)
          .completePrayer(groupId: widget.groupId, prayer: _selectedPrayer);
    } catch (_) {
      if (mounted) setState(() => _myStatus = previous);
    }
  }

  Future<void> _openPhotoCheckin(String groupId) async {
    final result = await context.push<bool>(
      '/home/groups/$groupId/photo-checkin',
      extra: _selectedPrayer.name,
    );
    if (result == true && mounted) {
      setState(() => _myStatus = CheckinStatus.completedWithPhoto);
      await _showMessage('Fotoğrafın gönderildi.');
    }
  }

  Future<void> _completeQada() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaza namazını tamamla'),
        content: Text(
          '${_selectedPrayer.label} namazını kaza olarak kıldığını kaydetmek istiyor musun?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaza kıldım'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final previous = _myStatus;
    setState(() => _myStatus = CheckinStatus.qadaCompleted);
    try {
      await ref
          .read(appRepositoryProvider)
          .completeQada(groupId: widget.groupId, prayer: _selectedPrayer);
    } catch (_) {
      if (mounted) {
        setState(() => _myStatus = previous);
        await _showMessage(
          'Kaza kaydı oluşturulamadı. Vakit henüz devam ediyor olabilir.',
        );
      }
    }
  }

  Future<void> _join() async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      final approved = await ref
          .read(appRepositoryProvider)
          .joinGroup(widget.groupId)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (!approved) setState(() => _joinRequested = true);
      await _showMessage(
        approved
            ? 'Gruba katıldın.'
            : 'Katılım isteğin yöneticilere gönderildi.',
      );
      if (approved && mounted) {
        setState(() => _groupData = _loadGroup());
      }
    } catch (error) {
      if (mounted) {
        await _showMessage(
          error.toString().contains('dolu')
              ? 'Bu grup dolu.'
              : 'Gruba katılamadın. Tekrar dene.',
        );
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _wake(String memberId) async {
    if (_busyMember != null) return;
    setState(() => _busyMember = memberId);
    try {
      await ref
          .read(appRepositoryProvider)
          .wakeMember(
            groupId: widget.groupId,
            memberId: memberId,
            prayer: _selectedPrayer,
          );
      if (mounted) await _showMessage('Hatırlatma gönderildi');
    } finally {
      if (mounted) setState(() => _busyMember = null);
    }
  }

  Future<void> _sendAdminReminder() async {
    if (_reminderSent) return;
    setState(() => _reminderSent = true);
    try {
      await ref
          .read(appRepositoryProvider)
          .sendAdminReminder(groupId: widget.groupId, prayer: _selectedPrayer);
      if (mounted) await _showMessage('Toplu hatırlatma gönderildi.');
    } catch (_) {
      if (mounted) {
        setState(() => _reminderSent = false);
        await _showMessage('Hatırlatma gönderilemedi veya günlük limit doldu.');
      }
    }
  }

  Future<void> _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 92),
      ),
    );
    return Future<void>.value();
  }

  Future<void> _shareGroup(GroupSummary group) async {
    final renderObject = context.findRenderObject();
    final origin = renderObject is RenderBox
        ? renderObject.localToGlobal(Offset.zero) & renderObject.size
        : null;
    await InviteService.instance.shareGroup(group, origin: origin);
  }

  Future<String?> _chooseReportReason(String title) => showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: <Widget>[
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'spam'),
          child: const Text('Spam veya yanıltıcı içerik'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'harassment'),
          child: const Text('Taciz veya uygunsuz davranış'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'unsafe_content'),
          child: const Text('Güvenli olmayan içerik'),
        ),
      ],
    ),
  );

  Future<void> _reportUser(GroupMember member) async {
    final reason = await _chooseReportReason(
      '${member.displayName} şikayet et',
    );
    if (reason == null || !mounted) return;
    try {
      await ref
          .read(appRepositoryProvider)
          .reportUser(userId: member.id, reason: reason);
      if (mounted) await _showMessage('Şikayetin incelemeye alındı.');
    } catch (_) {
      if (mounted) await _showMessage('Şikayet gönderilemedi.');
    }
  }

  Future<void> _reportGroup(GroupSummary group) async {
    final reason = await _chooseReportReason(
      '${group.name} grubunu şikayet et',
    );
    if (reason == null || !mounted) return;
    try {
      await ref
          .read(appRepositoryProvider)
          .reportGroup(groupId: group.id, reason: reason);
      if (mounted) await _showMessage('Şikayetin incelemeye alındı.');
    } catch (_) {
      if (mounted) await _showMessage('Şikayet gönderilemedi.');
    }
  }

  Future<void> _blockUser(GroupMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcıyı engelle'),
        content: Text(
          '${member.displayName} artık sana kişisel hatırlatma gönderemeyecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Engelle'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(appRepositoryProvider).blockUser(member.id);
      if (mounted) await _showMessage('Kullanıcı engellendi.');
    } catch (_) {
      if (mounted) await _showMessage('Kullanıcı engellenemedi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptivePage(
      title: 'Grup',
      body: FutureBuilder<_GroupDetailData>(
        future: _groupData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _GroupDetailSkeleton();
          }
          if (snapshot.hasError || snapshot.data?.group == null) {
            return _ErrorState(
              onRetry: () => setState(() => _groupData = _loadGroup()),
            );
          }
          final group = snapshot.data!.group!;
          final members = snapshot.data!.members;
          final windows = snapshot.data!.windows;
          final role =
              members
                  .where((member) => member.isCurrentUser)
                  .firstOrNull
                  ?.role ??
              GroupRole.member;
          final isMember = members.any((member) => member.isCurrentUser);
          final displayMembers = members.map((member) {
            if (!member.isCurrentUser) return member;
            return GroupMember(
              id: member.id,
              displayName: member.displayName,
              location: member.location,
              status: _myStatus,
              role: member.role,
              isCurrentUser: true,
            );
          }).toList();
          final completed = displayMembers
              .where(
                (member) =>
                    member.status == CheckinStatus.completed ||
                    member.status == CheckinStatus.completedWithPhoto,
              )
              .length;

          return RefreshIndicator.adaptive(
            onRefresh: () async {
              final next = _loadGroup();
              setState(() => _groupData = next);
              await next;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
              children: <Widget>[
                _GroupIdentity(
                  group: group,
                  role: role,
                  onShare: () => _shareGroup(group),
                  onReport: role.canManage ? null : () => _reportGroup(group),
                ),
                if (isMember)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        final result = await context.push<Object?>(
                          '/home/groups/${group.id}/settings',
                          extra: (group: group, role: role),
                        );
                        if (result != null && mounted) {
                          if (result == 'left') {
                            this.context.go('/home');
                          } else {
                            setState(() => _groupData = _loadGroup());
                          }
                        }
                      },
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('Grup ayarları'),
                    ),
                  ),
                if (!isMember) ...<Widget>[
                  const SizedBox(height: 18),
                  AdaptivePrimaryButton(
                    label: _joinRequested
                        ? 'Katılım isteği gönderildi'
                        : _joining
                        ? 'Katılınıyor…'
                        : group.joinApprovalRequired
                        ? 'Katılım isteği gönder'
                        : 'Gruba katıl',
                    onPressed: _joining || _joinRequested ? null : _join,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Gruba katıldığında günlük akışı ve üyeleri görebilirsin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
                if (isMember) ...<Widget>[
                  const SizedBox(height: 26),
                  _PrayerSelector(
                    prayers: group.prayers,
                    selected: _selectedPrayer,
                    windows: windows,
                    onSelected: _selectPrayer,
                  ),
                  const SizedBox(height: 14),
                  _TodayPanel(
                    prayer: _selectedPrayer,
                    window: windows[_selectedPrayer],
                    status: _myStatus,
                    completedCount: completed,
                    memberCount: group.memberCount,
                    onAwake: _markAwake,
                    onComplete: () => _complete(group),
                    onQada: _completeQada,
                  ),
                  if (role.canManage) ...<Widget>[
                    const SizedBox(height: 24),
                    _AdminTools(
                      reminderSent: _reminderSent,
                      pendingCount: displayMembers
                          .where(
                            (member) =>
                                member.status == CheckinStatus.pending ||
                                member.status == CheckinStatus.awake,
                          )
                          .length,
                      onRequests: () async {
                        await context.push<void>(
                          '/home/groups/${group.id}/join-requests',
                        );
                        if (mounted) {
                          setState(() => _groupData = _loadGroup());
                        }
                      },
                      onReminder: _sendAdminReminder,
                    ),
                  ],
                  const SizedBox(height: 30),
                  const SectionTitle('Bugün kim nerede?'),
                  const SizedBox(height: 8),
                  ...displayMembers.map(
                    (member) => _MemberRow(
                      member: member,
                      busy: _busyMember == member.id,
                      onWake:
                          !member.isCurrentUser &&
                              member.status == CheckinStatus.pending
                          ? () => _wake(member.id)
                          : null,
                      onBlock: member.isCurrentUser
                          ? null
                          : () => _blockUser(member),
                      onReport: member.isCurrentUser
                          ? null
                          : () => _reportUser(member),
                    ),
                  ),
                  if (group.verificationType ==
                      VerificationType.photo) ...<Widget>[
                    const SizedBox(height: 18),
                    AdaptiveSecondaryButton(
                      label: 'Fotoğrafla doğrula',
                      icon: Icons.camera_alt_outlined,
                      onPressed: () => _openPhotoCheckin(group.id),
                    ),
                    const SizedBox(height: 12),
                    PrayerPhotoStrip(
                      groupId: group.id,
                      prayer: _selectedPrayer,
                      members: displayMembers,
                    ),
                    const SizedBox(height: 12),
                    const _PhotoPrivacyNotice(),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GroupIdentity extends StatelessWidget {
  const _GroupIdentity({
    required this.group,
    required this.role,
    required this.onShare,
    required this.onReport,
  });

  final GroupSummary group;
  final GroupRole role;
  final VoidCallback onShare;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      GroupAvatar(group: group, size: 64),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              group.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -.4,
              ),
            ),
            const SizedBox(height: 4),
            if (role.canManage) ...<Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.orangePale,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    role.label,
                    style: const TextStyle(
                      color: AppColors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              '${group.city ?? group.country} · ${group.memberCount} üye · ${group.currentStreak} günlük seri',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ),
      ),
      IconButton(
        onPressed: onShare,
        tooltip: 'Grup davetini paylaş',
        icon: const Icon(Icons.ios_share_rounded, color: AppColors.brown),
      ),
      if (onReport != null)
        PopupMenuButton<String>(
          tooltip: 'Grup işlemleri',
          onSelected: (value) {
            if (value == 'report') onReport!();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'report', child: Text('Grubu şikayet et')),
          ],
        ),
    ],
  );
}

class _PrayerSelector extends StatelessWidget {
  const _PrayerSelector({
    required this.prayers,
    required this.selected,
    required this.windows,
    required this.onSelected,
  });

  final List<Prayer> prayers;
  final Prayer selected;
  final Map<Prayer, PrayerWindow> windows;
  final ValueChanged<Prayer> onSelected;

  @override
  Widget build(BuildContext context) {
    final available = prayers.isEmpty ? Prayer.values : prayers;
    return Semantics(
      label: 'Namaz seçimi',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: available.map((prayer) {
            final active = prayer == selected;
            final ended = windows[prayer]?.hasEnded ?? false;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: active,
                showCheckmark: false,
                label: Text(prayer.label),
                onSelected: (_) => onSelected(prayer),
                labelStyle: TextStyle(
                  color: ended
                      ? AppColors.muted
                      : active
                      ? Colors.white
                      : AppColors.brown,
                  fontWeight: FontWeight.w700,
                ),
                selectedColor: ended ? AppColors.line : AppColors.brown,
                backgroundColor: ended ? AppColors.warmWhite : Colors.white,
                side: BorderSide(
                  color: active && !ended ? AppColors.brown : AppColors.line,
                ),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TodayPanel extends StatelessWidget {
  const _TodayPanel({
    required this.prayer,
    required this.window,
    required this.status,
    required this.completedCount,
    required this.memberCount,
    required this.onAwake,
    required this.onComplete,
    required this.onQada,
  });

  final Prayer prayer;
  final PrayerWindow? window;
  final CheckinStatus status;
  final int completedCount;
  final int memberCount;
  final VoidCallback onAwake;
  final VoidCallback onComplete;
  final VoidCallback onQada;

  @override
  Widget build(BuildContext context) {
    final participation = memberCount == 0 ? 0.0 : completedCount / memberCount;
    final completed =
        status == CheckinStatus.completed ||
        status == CheckinStatus.completedWithPhoto ||
        status == CheckinStatus.qadaCompleted;
    final upcoming = window?.isUpcoming ?? false;
    final ended = window?.hasEnded ?? false;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'BUGÜN · ${prayer.label.toUpperCase()}',
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: .8,
                  ),
                ),
              ),
              Text(
                '$completedCount / $memberCount',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: participation,
            minHeight: 6,
            color: AppColors.green,
            backgroundColor: AppColors.greenPale,
          ),
          const SizedBox(height: 18),
          Text(
            completed
                ? status == CheckinStatus.qadaCompleted
                      ? '${prayer.label} namazını kaza olarak tamamladın.'
                      : 'Bugünkü ${prayer.label} namazını tamamladın.'
                : window == null
                ? 'Vakit bilgisi hazırlanıyor. Onay işlemleri şimdilik kapalı.'
                : upcoming
                ? '${prayer.label} vakti henüz girmedi. Vakit başlayınca onaylayabilirsin.'
                : ended
                ? 'Vakit geçti. Namazını kaza olarak tamamladığında kaydedebilirsin.'
                : status == CheckinStatus.pending
                ? 'Grubun seni bekliyor. ${prayer.label} vakti devam ediyor.'
                : status == CheckinStatus.awake
                ? 'Kalktın. Namazını tamamladığında işaretleyebilirsin.'
                : status == CheckinStatus.missed
                ? 'Vakit geçti. Namazını kaza olarak tamamladığında kaydedebilirsin.'
                : 'Bugünkü ${prayer.label} namazını tamamladın.',
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (!completed && window == null)
            const AdaptivePrimaryButton(
              label: 'Vakit bilgisi hazırlanıyor',
              icon: Icons.schedule_rounded,
              onPressed: null,
            )
          else if (!completed && upcoming)
            const AdaptivePrimaryButton(
              label: 'Vakit henüz girmedi',
              icon: Icons.schedule_rounded,
              onPressed: null,
            )
          else if (!completed && ended)
            AdaptiveSecondaryButton(
              label: 'Kaza kıldım',
              icon: Icons.history_rounded,
              onPressed: onQada,
            )
          else if (status == CheckinStatus.pending)
            Column(
              children: [
                AdaptivePrimaryButton(
                  label: 'Kalktım',
                  icon: Icons.alarm_on_outlined,
                  onPressed: onAwake,
                ),
                const SizedBox(height: 8),
                AdaptiveSecondaryButton(
                  label: 'Vakit geçtiyse kaza kıldım',
                  icon: Icons.history_rounded,
                  onPressed: onQada,
                ),
              ],
            )
          else if (status == CheckinStatus.awake)
            Column(
              children: [
                AdaptivePrimaryButton(
                  label: 'Kıldım',
                  icon: Icons.check_rounded,
                  onPressed: onComplete,
                ),
                const SizedBox(height: 8),
                AdaptiveSecondaryButton(
                  label: 'Vakit geçtiyse kaza kıldım',
                  icon: Icons.history_rounded,
                  onPressed: onQada,
                ),
              ],
            )
          else if (status == CheckinStatus.missed)
            AdaptiveSecondaryButton(
              label: 'Kaza kıldım',
              icon: Icons.history_rounded,
              onPressed: onQada,
            )
          else
            Row(
              children: <Widget>[
                const Icon(Icons.check_circle_rounded, color: AppColors.green),
                const SizedBox(width: 9),
                Text(
                  status == CheckinStatus.qadaCompleted
                      ? 'Kaza olarak tamamlandı'
                      : 'Tamamlandı',
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AdminTools extends StatelessWidget {
  const _AdminTools({
    required this.reminderSent,
    required this.pendingCount,
    required this.onRequests,
    required this.onReminder,
  });

  final bool reminderSent;
  final int pendingCount;
  final VoidCallback onRequests;
  final VoidCallback onReminder;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.line),
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Row(
          children: <Widget>[
            Icon(
              Icons.admin_panel_settings_outlined,
              color: AppColors.green,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Yönetici araçları',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '$pendingCount kişi henüz tamamlamadı.',
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: <Widget>[
            AdaptiveSecondaryButton(
              label: 'Katılım istekleri',
              onPressed: onRequests,
            ),
            AdaptiveSecondaryButton(
              label: reminderSent ? 'Hatırlatıldı' : 'Toplu Hatırlat',
              icon: reminderSent
                  ? Icons.check_rounded
                  : Icons.notifications_active_outlined,
              onPressed: reminderSent ? null : onReminder,
            ),
          ],
        ),
      ],
    ),
  );
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.busy,
    this.onWake,
    this.onBlock,
    this.onReport,
  });

  final GroupMember member;
  final bool busy;
  final VoidCallback? onWake;
  final VoidCallback? onBlock;
  final VoidCallback? onReport;

  IconData get _icon => switch (member.status) {
    CheckinStatus.completed => Icons.check_circle_outline_rounded,
    CheckinStatus.completedWithPhoto => Icons.photo_camera_outlined,
    CheckinStatus.awake => Icons.alarm_on_outlined,
    CheckinStatus.missed => Icons.timer_off_outlined,
    CheckinStatus.qadaCompleted => Icons.history_rounded,
    CheckinStatus.pending => Icons.bedtime_outlined,
  };

  Color get _color => switch (member.status) {
    CheckinStatus.completed ||
    CheckinStatus.completedWithPhoto => AppColors.green,
    CheckinStatus.awake => AppColors.amber,
    _ => AppColors.muted,
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      children: <Widget>[
        Icon(_icon, color: _color, size: 21),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      member.isCurrentUser
                          ? '${member.displayName} (Sen)'
                          : member.displayName,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (member.role.canManage) ...<Widget>[
                    const SizedBox(width: 6),
                    Text(
                      member.role.label,
                      style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${member.location} · ${member.status.label}',
                style: TextStyle(color: _color, fontSize: 12),
              ),
            ],
          ),
        ),
        if (onWake != null)
          AdaptiveSecondaryButton(
            label: busy ? 'Gönderiliyor' : 'Uyandır',
            icon: Icons.notifications_active_outlined,
            onPressed: busy ? null : onWake,
          ),
        if (onBlock != null || onReport != null)
          PopupMenuButton<String>(
            tooltip: 'Üye işlemleri',
            onSelected: (value) {
              if (value == 'block') onBlock?.call();
              if (value == 'report') onReport?.call();
            },
            itemBuilder: (context) => [
              if (onBlock != null)
                const PopupMenuItem(
                  value: 'block',
                  child: Text('Kullanıcıyı engelle'),
                ),
              if (onReport != null)
                const PopupMenuItem(
                  value: 'report',
                  child: Text('Kullanıcıyı şikayet et'),
                ),
            ],
          ),
      ],
    ),
  );
}

class _PhotoPrivacyNotice extends StatelessWidget {
  const _PhotoPrivacyNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7EC),
      borderRadius: BorderRadius.circular(24),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.lock_clock_outlined, color: AppColors.amber, size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Fotoğraflar yalnızca grup üyelerine görünür ve 12 saat sonra silinir.',
            style: TextStyle(color: AppColors.amber, fontSize: 13, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _GroupDetailSkeleton extends StatefulWidget {
  const _GroupDetailSkeleton();

  @override
  State<_GroupDetailSkeleton> createState() => _GroupDetailSkeletonState();
}

class _GroupDetailSkeletonState extends State<_GroupDetailSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: .42, end: .9).animate(_controller),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 120),
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.greenPale,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: _SkeletonBlock(height: 54)),
          ],
        ),
        const SizedBox(height: 28),
        const _SkeletonBlock(height: 210),
        const SizedBox(height: 22),
        const _SkeletonBlock(height: 64),
        const SizedBox(height: 10),
        const _SkeletonBlock(height: 64),
        const SizedBox(height: 10),
        const _SkeletonBlock(height: 64),
      ],
    ),
  );
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: AppColors.line),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.cloud_off_outlined,
            color: AppColors.muted,
            size: 38,
          ),
          const SizedBox(height: 12),
          const Text(
            'Grup yüklenemedi',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          AdaptiveSecondaryButton(label: 'Tekrar Dene', onPressed: onRetry),
        ],
      ),
    ),
  );
}
