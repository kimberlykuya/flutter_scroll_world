import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:padlo_poc/src/app.dart';
import 'package:padlo_poc/src/state/padlo_demo_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scrubs the real-time Padlo pilot forward and backward', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = PadloDemoStore();
    await store.load();
    await tester.pumpWidget(PadloApp(store: store));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('First serve'), findsOneWidget);
    final scrollTarget = find.byType(SingleChildScrollView);
    for (var i = 0; i < 8; i++) {
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(scrollTarget),
          scrollDelta: const Offset(0, 420),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Positioning lab'), findsOneWidget);

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(scrollTarget),
        scrollDelta: const Offset(0, -600),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('First serve'), findsOneWidget);
  });
}
