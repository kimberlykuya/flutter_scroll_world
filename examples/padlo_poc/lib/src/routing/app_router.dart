import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../screens/padlo_world_screen.dart';
import '../state/padlo_demo_store.dart';

GoRouter buildPadloRouter(PadloDemoStore store) => GoRouter(
  initialLocation: '/onboarding',
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
        _worldRoute('/register', pilotRedirect: true),
        _worldRoute('/app/home', pilotRedirect: true),
        _worldRoute('/app/record', pilotRedirect: true),
        _worldRoute(
          '/app/reports',
          pilotRedirect: true,
          routes: <RouteBase>[
            GoRoute(
              path: ':reportId',
              pageBuilder: (context, state) =>
                  const NoTransitionPage<void>(child: SizedBox.shrink()),
            ),
          ],
        ),
        _worldRoute('/app/profile', pilotRedirect: true),
      ],
    ),
  ],
  redirect: (context, state) => padloPilotRedirect(state.uri.path),
);

String? padloPilotRedirect(String path) {
  if (path == '/' || path == '/onboarding') return null;
  return Uri(
    path: '/onboarding',
    queryParameters: <String, String>{'from': path},
  ).toString();
}

GoRoute _worldRoute(
  String path, {
  List<RouteBase> routes = const <RouteBase>[],
  bool pilotRedirect = false,
}) => GoRoute(
  path: path,
  routes: routes,
  redirect: pilotRedirect
      ? (context, state) => padloPilotRedirect(state.uri.path)
      : null,
  pageBuilder: (context, state) =>
      const NoTransitionPage<void>(child: SizedBox.shrink()),
);
