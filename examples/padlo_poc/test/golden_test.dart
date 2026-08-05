import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padlo_poc/src/app.dart';
import 'package:padlo_poc/src/models/demo_models.dart';
import 'package:padlo_poc/src/state/padlo_demo_store.dart';
import 'package:scroll_world/scroll_world.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profile = DemoPlayerProfile(
  firstName: 'Luka',
  lastName: 'Novak',
  email: 'luka@example.com',
  level: PlayerLevel.intermediate,
  preferredSide: CourtSide.right,
  focus: PositioningFocus.recoveryTiming,
);

Future<PadloDemoStore> _store(
  String checkpoint, {
  bool registered = true,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'padlo_onboarding_complete': true,
    if (registered) 'padlo_demo_profile': _profile.toJson(),
    'padlo_world_checkpoint': checkpoint,
    'padlo_generated_report': true,
  });
  final store = PadloDemoStore();
  await store.load();
  return store;
}

Future<void> _pumpWorld(
  WidgetTester tester, {
  required Size size,
  required String checkpoint,
  bool registered = true,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final store = await _store(checkpoint, registered: registered);
  await tester.pumpWidget(
    PadloApp(
      store: store,
      disableAnimationsOverride: true,
      textScalerOverride: TextScaler.linear(textScale),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 100));
  final worldContext = tester.element(find.byType(ScrollWorldView));
  expect(MediaQuery.of(worldContext).disableAnimations, isTrue);
  expect(find.byType(CircularProgressIndicator), findsNothing);
  await tester.runAsync(
    () async {
      await precacheImage(
        AssetImage('assets/posters/$checkpoint.webp'),
        worldContext,
      );
      await precacheImage(
        const AssetImage('assets/brand/padlo-logo.png'),
        worldContext,
      );
    },
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader('Epilogue')
      ..addFont(rootBundle.load('assets/fonts/Epilogue-VariableFont_wght.ttf'));
    await loader.load();
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      final iconFile = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (iconFile.existsSync()) {
        final iconLoader = FontLoader('MaterialIcons')
          ..addFont(iconFile.readAsBytes().then(ByteData.sublistView));
        await iconLoader.load();
      }
    }
  });

  testWidgets('mobile player setup gate', (tester) async {
    await _pumpWorld(
      tester,
      size: const Size(390, 844),
      checkpoint: 'player-setup',
      registered: false,
    );
    expect(find.text('Unlock your positioning room.'), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/world-player-setup-mobile.png'),
    );
  });

  testWidgets('tablet clubhouse at 200 percent text', (tester) async {
    await _pumpWorld(
      tester,
      size: const Size(834, 1194),
      checkpoint: 'clubhouse',
      textScale: 2,
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/world-clubhouse-tablet-text-200.png'),
    );
  });

  testWidgets('desktop tactical replay arena', (tester) async {
    await _pumpWorld(
      tester,
      size: const Size(1440, 1024),
      checkpoint: 'replay-arena',
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/world-replay-desktop.png'),
    );
  });

  testWidgets('mobile profile locker', (tester) async {
    await _pumpWorld(
      tester,
      size: const Size(390, 844),
      checkpoint: 'profile-locker',
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/world-profile-mobile.png'),
    );
  });
}
