import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../screens/home_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/record_screen.dart';
import '../screens/registration_screen.dart';
import '../screens/report_detail_screen.dart';
import '../screens/reports_screen.dart';
import '../state/padlo_demo_store.dart';
import '../widgets/padlo_shell.dart';

GoRouter buildPadloRouter(PadloDemoStore store) => GoRouter(
  initialLocation: store.isRegistered
      ? '/app/home'
      : store.onboardingComplete
      ? '/register'
      : '/onboarding',
  refreshListenable: store,
  routes: <RouteBase>[
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) =>
          RegistrationScreen(returnPath: state.uri.queryParameters['from']),
    ),
    ShellRoute(
      builder: (context, state, child) =>
          PadloShell(currentLocation: state.uri.path, child: child),
      routes: <RouteBase>[
        GoRoute(
          path: '/app/home',
          pageBuilder: (context, state) => _fadePage(state, const HomeScreen()),
        ),
        GoRoute(
          path: '/app/record',
          pageBuilder: (context, state) =>
              _fadePage(state, const RecordScreen()),
        ),
        GoRoute(
          path: '/app/reports',
          pageBuilder: (context, state) =>
              _fadePage(state, const ReportsScreen()),
          routes: <RouteBase>[
            GoRoute(
              path: ':reportId',
              pageBuilder: (context, state) => _fadePage(
                state,
                ReportDetailScreen(reportId: state.pathParameters['reportId']!),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/app/profile',
          pageBuilder: (context, state) =>
              _fadePage(state, const ProfileScreen()),
        ),
      ],
    ),
  ],
  redirect: (context, state) {
    final protected = state.uri.path.startsWith('/app/');
    if (protected && !store.isRegistered) {
      return Uri(
        path: '/register',
        queryParameters: <String, String>{'from': state.uri.path},
      ).toString();
    }
    if (state.uri.path == '/') {
      return store.isRegistered ? '/app/home' : '/onboarding';
    }
    return null;
  },
);

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );
