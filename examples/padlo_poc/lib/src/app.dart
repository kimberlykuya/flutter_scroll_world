import 'package:flutter/material.dart';

import 'routing/app_router.dart';
import 'state/padlo_demo_store.dart';
import 'theme/padlo_theme.dart';

final class PadloApp extends StatefulWidget {
  const PadloApp({required this.store, super.key});

  final PadloDemoStore store;

  @override
  State<PadloApp> createState() => _PadloAppState();
}

final class _PadloAppState extends State<PadloApp> {
  late final router = buildPadloRouter(widget.store);

  @override
  void dispose() {
    router.dispose();
    widget.store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PadloScope(
    store: widget.store,
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Padlo positioning coach — proof of concept',
      theme: buildPadloTheme(Brightness.light),
      darkTheme: buildPadloTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: router,
    ),
  );
}

final class PadloScope extends InheritedNotifier<PadloDemoStore> {
  const PadloScope({
    required PadloDemoStore store,
    required super.child,
    super.key,
  }) : super(notifier: store);

  static PadloDemoStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PadloScope>();
    assert(scope != null, 'PadloScope is missing above this context.');
    return scope!.notifier!;
  }
}
