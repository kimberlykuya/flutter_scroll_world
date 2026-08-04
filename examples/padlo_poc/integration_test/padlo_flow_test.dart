import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:padlo_poc/src/app.dart';
import 'package:padlo_poc/src/state/padlo_demo_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('complete local Padlo journey', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    final store = PadloDemoStore();
    await store.load();
    await tester.pumpWidget(PadloApp(store: store));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(find.text('Create demo account'), findsOneWidget);
    await tester.tap(find.text('Create demo account'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('create-demo-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-demo-account')));
    await tester.pumpAndSettle();
    expect(find.text('Dobrodošel, Luka.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.videocam_outlined).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('analyze-demo-match')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('analyze-demo-match')));
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open positioning report'));
    await tester.pumpAndSettle();

    expect(find.text('Four signals. One clear priority.'), findsOneWidget);
    expect(find.text('Ljubljana', findRichText: true), findsWidgets);
  });
}
