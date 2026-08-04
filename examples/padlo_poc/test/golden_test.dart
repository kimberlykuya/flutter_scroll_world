import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padlo_poc/src/app.dart';
import 'package:padlo_poc/src/models/demo_models.dart';
import 'package:padlo_poc/src/screens/home_screen.dart';
import 'package:padlo_poc/src/screens/onboarding_screen.dart';
import 'package:padlo_poc/src/screens/report_detail_screen.dart';
import 'package:padlo_poc/src/state/padlo_demo_store.dart';
import 'package:padlo_poc/src/theme/padlo_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<PadloDemoStore> _store() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final store = PadloDemoStore();
  await store.load();
  await store.register(
    const DemoPlayerProfile(
      firstName: 'Luka',
      lastName: 'Novak',
      email: 'luka@example.com',
      level: PlayerLevel.intermediate,
      preferredSide: CourtSide.right,
      focus: PositioningFocus.recoveryTiming,
    ),
  );
  return store;
}

Widget _host(PadloDemoStore store, Widget child, {double textScale = 1}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildPadloTheme(Brightness.light),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: PadloScope(
          store: store,
          child: Scaffold(body: child),
        ),
      ),
    );

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

  testWidgets('mobile home golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = await _store();
    await tester.pumpWidget(_host(store, const HomeScreen()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/home-mobile.png'),
    );
  });

  testWidgets('tablet home at 200 percent text golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(834, 1194));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = await _store();
    await tester.pumpWidget(_host(store, const HomeScreen(), textScale: 2));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/home-tablet-text-200.png'),
    );
  });

  testWidgets('desktop tactical report golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = await _store();
    await tester.pumpWidget(
      _host(store, ReportDetailScreen(reportId: featuredReport.id)),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/report-desktop.png'),
    );
  });

  testWidgets('reduced-motion final onboarding golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    final store = await _store();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPadloTheme(Brightness.light),
        home: PadloScope(store: store, child: const OnboardingScreen()),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/onboarding-final-reduced-motion.png'),
    );
  });
}
