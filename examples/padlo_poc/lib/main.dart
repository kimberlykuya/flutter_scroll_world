import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/platform/padlo_web_plugins.dart';
import 'src/state/padlo_demo_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerPadloWebPlugins();
  final store = PadloDemoStore();
  await store.load();
  runApp(PadloApp(store: store));
}
