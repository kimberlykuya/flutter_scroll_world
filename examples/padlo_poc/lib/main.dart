import 'dart:async';

import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/platform/padlo_web_plugins.dart';
import 'src/state/padlo_demo_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerPadloWebPlugins();
  final store = PadloDemoStore();
  runApp(PadloApp(store: store));
  unawaited(store.load());
}
