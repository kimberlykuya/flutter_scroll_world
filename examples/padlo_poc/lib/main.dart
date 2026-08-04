import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/state/padlo_demo_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = PadloDemoStore();
  await store.load();
  runApp(PadloApp(store: store));
}
