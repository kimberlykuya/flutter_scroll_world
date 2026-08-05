import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../screens/padlo_world_screen.dart';
import '../state/padlo_demo_store.dart';

GoRouter buildPadloRouter(PadloDemoStore store) => GoRouter(
  initialLocation: _initialLocation(store),
  refreshListenable: store,
  routes: <RouteBase>[
    GoRoute(path: '/', redirect: (context, state) => '/onboarding'),
    ShellRoute(
      builder: (context, state, child) => PadloWorldScreen(
        routeLocation: state.uri.toString(),
        routeChild: child,
      ),
      routes: <RouteBase>[
        _worldRoute('/onboarding'),
        _worldRoute('/register'),
        _worldRoute('/app/home'),
        _worldRoute('/app/record'),
        _worldRoute(
          '/app/reports',
          routes: <RouteBase>[
            GoRoute(
              path: ':reportId',
              pageBuilder: (context, state) =>
                  const NoTransitionPage<void>(child: SizedBox.shrink()),
            ),
          ],
        ),
        _worldRoute('/app/profile'),
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
    return null;
  },
);

String _initialLocation(PadloDemoStore store) {
  if (!store.isRegistered) {
    return store.onboardingComplete ? '/register' : '/onboarding';
  }
  return switch (store.worldCheckpoint) {
    'player-setup' => '/register',
    'clubhouse' => '/app/home',
    'analysis-court' => '/app/record',
    'report-vault' => '/app/reports',
    'replay-arena' => '/app/reports/${store.selectedReportId}',
    'profile-locker' => '/app/profile',
    _ => '/app/home',
  };
}

GoRoute _worldRoute(
  String path, {
  List<RouteBase> routes = const <RouteBase>[],
}) => GoRoute(
  path: path,
  routes: routes,
  pageBuilder: (context, state) =>
      const NoTransitionPage<void>(child: SizedBox.shrink()),
);
