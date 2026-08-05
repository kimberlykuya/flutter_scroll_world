import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:padlo_poc/src/app.dart';
import 'package:padlo_poc/src/state/padlo_demo_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('complete local journey through the spatial product world', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'padlo_onboarding_complete': true,
    });
    final store = PadloDemoStore();
    await store.load();
    await tester.pumpWidget(
      PadloApp(store: store, disableAnimationsOverride: true),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Unlock your positioning room.'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('create-demo-account')));
    await tester.tap(find.byKey(const Key('create-demo-account')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Analysis court'), findsOneWidget);

    await tester.tap(find.text('Analysis court'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byKey(const Key('analyze-demo-match')));
    await tester.pump(const Duration(milliseconds: 1100));
    expect(store.hasGeneratedReport, isTrue);

    await tester.tap(find.text('Enter the replay arena'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.textContaining('Ljubljana'), findsWidgets);
    expect(find.textContaining('Kovač'), findsWidgets);
  });
}
