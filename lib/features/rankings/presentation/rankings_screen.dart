import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/repository_provider.dart';
import '../../../core/domain/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive_page.dart';

class RankingsScreen extends ConsumerStatefulWidget {
  const RankingsScreen({super.key});

  @override
  ConsumerState<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends ConsumerState<RankingsScreen> {
  int _days = 7;

  @override
  Widget build(BuildContext context) => AdaptivePage(
    title: 'Grup Sıralaması',
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
      children: <Widget>[
        const Text(
          'Sıralama kişileri değil, grupların düzenli katılımını gösterir.',
          style: TextStyle(color: AppColors.muted, fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: CupertinoSlidingSegmentedControl<int>(
            groupValue: _days,
            thumbColor: Colors.white,
            backgroundColor: AppColors.brownPale,
            children: const <int, Widget>{
              7: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('7 gün'),
              ),
              30: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('30 gün'),
              ),
            },
            onValueChanged: (value) => setState(() => _days = value ?? 7),
          ),
        ),
        const SizedBox(height: 22),
        FutureBuilder<List<RankingEntry>>(
          future: ref.read(appRepositoryProvider).rankings(days: _days),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _RankingSkeleton();
            }
            final entries = snapshot.data ?? const <RankingEntry>[];
            return Column(
              children: List<Widget>.generate(
                entries.length,
                (index) =>
                    _RankingRow(position: index + 1, entry: entries[index]),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.greenMist,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.greenPale),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.balance_outlined, color: AppColors.green, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Listeye yalnızca en az 5 aktif üyesi ve 7 günlük geçmişi olan gruplar girer. Kişisel sıralama yapılmaz.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.position, required this.entry});

  final int position;
  final RankingEntry entry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      children: <Widget>[
        SizedBox(
          width: 38,
          child: Text(
            '$position',
            style: TextStyle(
              color: position <= 3 ? AppColors.orange : AppColors.muted,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                entry.groupName,
                style: const TextStyle(
                  color: AppColors.brown,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${entry.activeMembers} aktif üye',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        Text(
          '%${(entry.score * 100).toStringAsFixed(1)}',
          style: const TextStyle(
            color: AppColors.green,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ],
    ),
  );
}

class _RankingSkeleton extends StatefulWidget {
  const _RankingSkeleton();

  @override
  State<_RankingSkeleton> createState() => _RankingSkeletonState();
}

class _RankingSkeletonState extends State<_RankingSkeleton>
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
    opacity: Tween<double>(begin: .4, end: .88).animate(_controller),
    child: Column(
      children: List<Widget>.generate(
        5,
        (index) => Container(
          height: 65,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.line),
          ),
        ),
      ),
    ),
  );
}
