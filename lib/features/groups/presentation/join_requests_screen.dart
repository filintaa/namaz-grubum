import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/repository_provider.dart';
import '../../../core/domain/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive_page.dart';

class JoinRequestsScreen extends ConsumerStatefulWidget {
  const JoinRequestsScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends ConsumerState<JoinRequestsScreen> {
  late Future<List<GroupJoinRequest>> _requests;
  final Set<String> _busyUsers = <String>{};
  int _resolvedCount = 0;

  @override
  void initState() {
    super.initState();
    _requests = ref
        .read(appRepositoryProvider)
        .pendingJoinRequests(widget.groupId);
  }

  void _reload() {
    setState(() {
      _requests = ref
          .read(appRepositoryProvider)
          .pendingJoinRequests(widget.groupId);
    });
  }

  Future<void> _resolve(GroupJoinRequest request, bool approve) async {
    if (_busyUsers.contains(request.userId)) return;
    setState(() => _busyUsers.add(request.userId));
    try {
      await ref
          .read(appRepositoryProvider)
          .resolveJoinRequest(
            groupId: widget.groupId,
            userId: request.userId,
            approve: approve,
          );
      if (!mounted) return;
      setState(() {
        _resolvedCount += 1;
        _busyUsers.remove(request.userId);
        _requests = _requests.then(
          (items) =>
              items.where((item) => item.userId != request.userId).toList(),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? '${request.displayName} gruba katıldı.'
                : '${request.displayName} için istek reddedildi.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyUsers.remove(request.userId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İstek işlenemedi. Tekrar deneyin.')),
      );
    }
  }

  String _relativeTime(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Şimdi';
    if (difference.inHours < 1) return '${difference.inMinutes} dk önce';
    if (difference.inDays < 1) return '${difference.inHours} sa önce';
    if (difference.inDays < 7) return '${difference.inDays} gün önce';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => AdaptivePage(
    title: 'Katılım istekleri',
    body: FutureBuilder<List<GroupJoinRequest>>(
      future: _requests,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        if (snapshot.hasError) {
          return _RequestsMessage(
            icon: Icons.cloud_off_outlined,
            title: 'İstekler yüklenemedi',
            detail: 'Bağlantını kontrol edip tekrar deneyebilirsin.',
            action: 'Tekrar dene',
            onAction: _reload,
          );
        }
        final requests = snapshot.data ?? const <GroupJoinRequest>[];
        if (requests.isEmpty) {
          return _RequestsMessage(
            icon: Icons.how_to_reg_rounded,
            title: 'Bekleyen istek yok',
            detail: _resolvedCount > 0
                ? 'Tüm katılım isteklerini değerlendirdin.'
                : 'Yeni bir istek geldiğinde burada görünecek.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
          children: <Widget>[
            Text(
              '${requests.length} kişi bekliyor',
              style: const TextStyle(
                color: AppColors.brown,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Her isteği kabul edebilir veya reddedebilirsin.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            ...requests.indexed.map((entry) {
              final index = entry.$1;
              final request = entry.$2;
              return TweenAnimationBuilder<double>(
                key: ValueKey(request.userId),
                duration: Duration(milliseconds: 260 + index * 55),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - value)),
                    child: child,
                  ),
                ),
                child: _RequestRow(
                  request: request,
                  relativeTime: _relativeTime(request.createdAt),
                  busy: _busyUsers.contains(request.userId),
                  onApprove: () => _resolve(request, true),
                  onReject: () => _resolve(request, false),
                ),
              );
            }),
          ],
        );
      },
    ),
  );
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.request,
    required this.relativeTime,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final GroupJoinRequest request;
  final String relativeTime;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 17),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            CircleAvatar(
              radius: 23,
              backgroundColor: AppColors.greenPale,
              child: Text(
                request.displayName.characters.first.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.green,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    request.displayName,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${request.location.isEmpty ? 'Konum belirtilmedi' : request.location} · $relativeTime',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 13),
        Row(
          children: <Widget>[
            Expanded(
              child: AdaptiveSecondaryButton(
                label: 'Reddet',
                onPressed: busy ? null : onReject,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AdaptivePrimaryButton(
                label: 'Kabul et',
                onPressed: busy ? null : onApprove,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _RequestsMessage extends StatelessWidget {
  const _RequestsMessage({
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 42, color: AppColors.green),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: 18),
            AdaptiveSecondaryButton(label: action!, onPressed: onAction),
          ],
        ],
      ),
    ),
  );
}
