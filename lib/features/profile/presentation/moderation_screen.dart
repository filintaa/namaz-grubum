import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive_page.dart';

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
  late Future<List<Map<String, dynamic>>> _reports = _load();
  bool _resolved = false;
  String? _busyId;

  Future<List<Map<String, dynamic>>> _load() async {
    final result = await _functions.httpsCallable('listModerationReports').call(
      <String, Object>{'status': _resolved ? 'resolved' : 'pending'},
    );
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['reports'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  void _showResolved(bool value) {
    setState(() {
      _resolved = value;
      _reports = _load();
    });
  }

  Future<void> _resolve(Map<String, dynamic> report, String resolution) async {
    final id = report['id'] as String;
    setState(() => _busyId = id);
    try {
      await _functions.httpsCallable('resolveModerationReport').call(
        <String, Object>{'reportId': id, 'resolution': resolution},
      );
      if (mounted) setState(() => _reports = _load());
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'Karar kaydedilemedi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) => AdaptivePage(
    title: 'Moderasyon',
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Bekleyen')),
              ButtonSegment(value: true, label: Text('Sonuçlanan')),
            ],
            selected: <bool>{_resolved},
            onSelectionChanged: (value) => _showResolved(value.first),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _reports,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator.adaptive(),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: AdaptiveSecondaryButton(
                    label: 'Tekrar dene',
                    onPressed: () => setState(() => _reports = _load()),
                  ),
                );
              }
              final reports = snapshot.data ?? const [];
              if (reports.isEmpty) {
                return Center(
                  child: Text(
                    _resolved
                        ? 'Sonuçlanan şikayet yok.'
                        : 'Bekleyen şikayet yok.',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                );
              }
              return RefreshIndicator.adaptive(
                onRefresh: () async {
                  final next = _load();
                  setState(() => _reports = next);
                  await next;
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 80),
                  itemCount: reports.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return _ReportRow(
                      report: report,
                      busy: _busyId == report['id'],
                      onResolve: _resolved
                          ? null
                          : (resolution) => _resolve(report, resolution),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.report,
    required this.busy,
    required this.onResolve,
  });

  final Map<String, dynamic> report;
  final bool busy;
  final ValueChanged<String>? onResolve;

  @override
  Widget build(BuildContext context) {
    final targetType = switch (report['targetType']) {
      'photo' => 'Fotoğraf',
      'user' => 'Kullanıcı',
      'group' => 'Grup',
      _ => 'İçerik',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.flag_outlined, color: AppColors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$targetType · ${report['targetLabel']}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Neden: ${report['reason']}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                if (report['resolution'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Karar: ${report['resolution']}',
                    style: const TextStyle(color: AppColors.green),
                  ),
                ],
              ],
            ),
          ),
          if (busy)
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          else if (onResolve != null)
            PopupMenuButton<String>(
              tooltip: 'Moderasyon kararı',
              onSelected: onResolve,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'dismissed',
                  child: Text('İşlem uygulama'),
                ),
                if (report['targetType'] != 'user')
                  const PopupMenuItem(
                    value: 'content_removed',
                    child: Text('İçeriği kaldır'),
                  ),
                const PopupMenuItem(
                  value: 'account_suspended',
                  child: Text('Hesabı askıya al'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
