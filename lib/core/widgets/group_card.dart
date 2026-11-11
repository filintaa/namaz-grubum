import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../theme/app_theme.dart';
import 'group_avatar.dart';

class GroupCard extends StatelessWidget {
  const GroupCard({required this.group, required this.onTap, super.key});

  final GroupSummary group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${group.name}, ${group.memberCount} üye, yüzde ${(group.participationRate * 100).round()} katılım',
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.line, width: .7),
          ),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  GroupAvatar(group: group),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          group.name,
                          style: const TextStyle(
                            color: AppColors.brown,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          group.city == null
                              ? group.country
                              : '${group.city}, ${group.country}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.greenMist,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '%${(group.participationRate * 100).round()}',
                      style: const TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  _Stat(
                    icon: Icons.people_outline_rounded,
                    value: '${group.memberCount}/${group.capacity}',
                  ),
                  const _Dot(),
                  _Stat(
                    icon: Icons.local_fire_department_outlined,
                    value: '${group.currentStreak} gün',
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.brownSoft,
                    size: 19,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: group.participationRate,
                  minHeight: 7,
                  color: AppColors.green,
                  backgroundColor: AppColors.greenPale,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Icon(icon, size: 17, color: AppColors.muted),
      const SizedBox(width: 5),
      Text(
        value,
        style: const TextStyle(
          color: AppColors.muted,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    ],
  );
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 9),
    child: CircleAvatar(radius: 2, backgroundColor: AppColors.line),
  );
}
