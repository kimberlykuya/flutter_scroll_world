import 'package:flutter/gestures.dart';
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

  setUp(() {
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  });

  tearDown(
    () => TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue(),
  );

  testWidgets('world HUD follows the active scene while scrolling', (
    tester,
  ) async {
    final store = await _loadedStore(<String, Object>{});
    await tester.pumpWidget(PadloApp(store: store));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('1 / 10'), findsOneWidget);
    final position = tester.getCenter(
      find.text('Read the point before it happens.'),
    );
    for (var index = 0; index < 3; index++) {
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: position,
          scrollDelta: const Offset(0, 600),
        ),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('2 / 10'), findsOneWidget);
  });

  testWidgets('player setup is an in-world gate and unlocks the clubhouse', (
    tester,
  ) async {
    final store = await _loadedStore(<String, Object>{
      'padlo_onboarding_complete': true,
    });
    await tester.pumpWidget(PadloApp(store: store));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Unlock your positioning room.'), findsOneWidget);
    expect(find.byKey(const Key('create-demo-account')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('create-demo-account')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('create-demo-account')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(store.isRegistered, isTrue);
    expect(find.textContaining('Luka'), findsWidgets);
    expect(find.text('Analysis court'), findsOneWidget);
    expect(find.text('Report vault'), findsOneWidget);
  });

  testWidgets('clubhouse portal launches deterministic court analysis', (
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('Analysis court'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const Key('analyze-demo-match')), findsOneWidget);

    await tester.tap(find.byKey(const Key('analyze-demo-match')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    expect(store.hasGeneratedReport, isTrue);
    expect(find.text('Enter the replay arena'), findsOneWidget);
  });

  testWidgets('protected deep link lands at the non-bypassable setup gate', (
    tester,
  ) async {
    final store = await _loadedStore(<String, Object>{
      'padlo_onboarding_complete': true,
      'padlo_world_checkpoint': 'replay-arena',
    });
    await tester.pumpWidget(PadloApp(store: store));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump(const Duration(milliseconds: 150));

    expect(store.isRegistered, isFalse);
    expect(find.text('Unlock your positioning room.'), findsOneWidget);
    expect(find.byKey(const Key('create-demo-account')), findsOneWidget);
  });
}
