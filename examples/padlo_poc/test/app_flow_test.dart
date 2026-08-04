import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padlo_poc/src/app.dart';
import 'package:padlo_poc/src/models/demo_models.dart';
import 'package:padlo_poc/src/state/padlo_demo_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<PadloDemoStore> _loadedStore(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  final store = PadloDemoStore();
  await store.load();
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mock registration unlocks the Slovenian home dashboard', (
    tester,
  ) async {
    final store = await _loadedStore(<String, Object>{
      'padlo_onboarding_complete': true,
    });
    await tester.pumpWidget(PadloApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Set up your court view'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('create-demo-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-demo-account')));
    await tester.pumpAndSettle();

    expect(find.text('Dobrodošel, Luka.'), findsOneWidget);
    expect(find.text('Your Slovenian match trail'), findsOneWidget);
    expect(store.isRegistered, isTrue);
  });

  testWidgets('deterministic analysis reaches the featured report', (
    tester,
  ) async {
    const profile = DemoPlayerProfile(
      firstName: 'Luka',
      lastName: 'Novak',
      email: 'luka@example.com',
      level: PlayerLevel.intermediate,
      preferredSide: CourtSide.right,
      focus: PositioningFocus.recoveryTiming,
    );
    final store = await _loadedStore(<String, Object>{
      'padlo_onboarding_complete': true,
      'padlo_demo_profile': profile.toJson(),
    });
    await tester.pumpWidget(PadloApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.videocam_outlined).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('analyze-demo-match')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('analyze-demo-match')));
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pumpAndSettle();

    expect(find.text('Your Ljubljana report is ready'), findsOneWidget);
    expect(store.hasGeneratedReport, isTrue);
    await tester.tap(find.text('Open positioning report'));
    await tester.pumpAndSettle();
    expect(find.text('Four signals. One clear priority.'), findsOneWidget);
    expect(find.textContaining('Kovač'), findsOneWidget);
  });

  testWidgets('reduced-motion onboarding exposes final actions', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    final store = await _loadedStore(<String, Object>{});
    await tester.pumpWidget(PadloApp(store: store));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();

    expect(find.text('Create demo account'), findsOneWidget);
    expect(find.text('Replay the tour'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Replay the Padlo positioning tour backwards'),
      findsOneWidget,
    );
  });
}
