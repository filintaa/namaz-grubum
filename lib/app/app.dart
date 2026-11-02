import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/domain/models.dart';
import '../core/services/app_session_controller.dart';

import '../core/theme/app_theme.dart';
import '../features/groups/presentation/create_group_screen.dart';
import '../features/groups/presentation/group_detail_screen.dart';
import '../features/groups/presentation/group_settings_screen.dart';
import '../features/groups/presentation/join_requests_screen.dart';
import '../features/groups/presentation/member_management_screen.dart';
import '../features/groups/presentation/my_groups_screen.dart';
import '../features/groups/presentation/photo_checkin_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/profile/presentation/moderation_screen.dart';
import '../features/profile/presentation/legal_document_screen.dart';
import '../features/profile/presentation/account_suspended_screen.dart';
import '../features/rankings/presentation/rankings_screen.dart';
import 'navigation/app_shell.dart';
import '../l10n/generated/app_localizations.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: const String.fromEnvironment(
    'INITIAL_ROUTE',
    defaultValue: '/onboarding',
  ),
  refreshListenable: AppSessionController.instance,
  redirect: (context, state) {
    final session = AppSessionController.instance;
    if (!session.initialized) return null;
    final onboarding = state.matchedLocation == '/onboarding';
    final legal = state.matchedLocation.startsWith('/legal/');
    final suspended = state.matchedLocation == '/account-suspended';
    if (session.accountSuspended && !suspended && !legal) {
      return '/account-suspended';
    }
    if (!session.accountSuspended && suspended) return '/home';
    if (!session.onboardingComplete && !onboarding && !legal) {
      return '/onboarding';
    }
    if (session.onboardingComplete && onboarding) return '/home';
    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/moderation',
      builder: (context, state) => const ModerationScreen(),
    ),
    GoRoute(
      path: '/account-suspended',
      builder: (context, state) => const AccountSuspendedScreen(),
    ),
    GoRoute(
      path: '/legal/:document',
      builder: (context, state) =>
          LegalDocumentScreen(document: state.pathParameters['document']!),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
              routes: <RouteBase>[
                GoRoute(
                  path: 'groups/:groupId',
                  builder: (context, state) => GroupDetailScreen(
                    groupId: state.pathParameters['groupId']!,
                  ),
                ),
                GoRoute(
                  path: 'groups/:groupId/settings',
                  builder: (context, state) {
                    final extra =
                        state.extra! as ({GroupSummary group, GroupRole role});
                    return GroupSettingsScreen(
                      group: extra.group,
                      role: extra.role,
                    );
                  },
                ),
                GoRoute(
                  path: 'groups/:groupId/photo-checkin',
                  builder: (context, state) => PhotoCheckinScreen(
                    groupId: state.pathParameters['groupId']!,
                    prayer: state.extra! as String,
                  ),
                ),
                GoRoute(
                  path: 'groups/:groupId/join-requests',
                  builder: (context, state) => JoinRequestsScreen(
                    groupId: state.pathParameters['groupId']!,
                  ),
                ),
                GoRoute(
                  path: 'groups/:groupId/members',
                  builder: (context, state) => MemberManagementScreen(
                    groupId: state.pathParameters['groupId']!,
                    currentRole: state.extra! as GroupRole,
                  ),
                ),
                GoRoute(
                  path: 'create-group',
                  builder: (context, state) => const CreateGroupScreen(),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/group',
              builder: (context, state) => const MyGroupsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/rankings',
              builder: (context, state) => const RankingsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

class NamazGrubumApp extends StatelessWidget {
  const NamazGrubumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.materialLight,
      darkTheme: AppTheme.materialLight,
      themeMode: ThemeMode.light,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: .85,
              maxScaleFactor: 2,
            ),
          ),
          child: child!,
        );
      },
      routerConfig: appRouter,
    );
  }
}
