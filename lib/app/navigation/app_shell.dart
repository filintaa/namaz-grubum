import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final destinations = <({IconData icon, IconData selected, String label})>[
      (
        icon: Icons.home_outlined,
        selected: Icons.home_rounded,
        label: strings.home,
      ),
      (
        icon: Icons.groups_outlined,
        selected: Icons.groups_rounded,
        label: strings.myGroups,
      ),
      (
        icon: Icons.leaderboard_outlined,
        selected: Icons.leaderboard_rounded,
        label: strings.rankings,
      ),
      (
        icon: Icons.person_outline_rounded,
        selected: Icons.person_rounded,
        label: strings.profile,
      ),
    ];
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .96),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.line, width: .7),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x175B3E2B),
                blurRadius: 26,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: List<Widget>.generate(destinations.length, (index) {
              final item = destinations[index];
              final selected = navigationShell.currentIndex == index;
              return Expanded(
                child: Semantics(
                  selected: selected,
                  button: true,
                  label: item.label,
                  child: InkWell(
                    onTap: () => _onTap(index),
                    borderRadius: BorderRadius.circular(22),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.greenMist
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          AnimatedScale(
                            scale: selected ? 1.06 : 1,
                            duration: const Duration(milliseconds: 220),
                            child: Icon(
                              selected ? item.selected : item.icon,
                              size: 22,
                              color: selected
                                  ? AppColors.brown
                                  : AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            maxLines: 1,
                            style: TextStyle(
                              color: selected
                                  ? AppColors.brown
                                  : AppColors.muted,
                              fontSize: 10,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
