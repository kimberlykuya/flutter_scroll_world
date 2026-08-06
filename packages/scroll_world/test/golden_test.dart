import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_world/scroll_world.dart';

final Uint8List _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

const double _goldenDiffTolerance = 0.002;

List<ScrollWorldScene> goldenScenes() => <ScrollWorldScene>[
  ScrollWorldScene(
    id: 'nairobi',
    title: 'Nairobi wakes in motion',
    description: 'Ideas and makers move the city forward.',
    sources: const ScrollWorldSources(
      webStandard: ScrollWorldSource.asset('one.mp4'),
    ),
    poster: MemoryImage(_pixel),
    transitionExtent: 0.5,
  ),
  ScrollWorldScene(
    id: 'highlands',
    title: 'Growth begins here',
    description: 'Rich soil connects every harvest to home.',
    sources: const ScrollWorldSources(
      webStandard: ScrollWorldSource.asset('two.mp4'),
    ),
    poster: MemoryImage(_pixel),
    transitionExtent: 0.5,
  ),
  ScrollWorldScene(
    id: 'coast',
    title: 'Everything flows outward',
    description: 'Kenya meets the ocean with confidence.',
    sources: const ScrollWorldSources(
      webStandard: ScrollWorldSource.asset('three.mp4'),
    ),
    poster: MemoryImage(_pixel),
    transitionExtent: 0,
    actions: const <ScrollWorldAction>[
      ScrollWorldAction.replayReverse(
        id: 'replay',
        label: 'Replay the journey',
      ),
    ],
  ),
];

Future<void> setSurface(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget goldenHost(
  ScrollController controller, {
  List<ScrollWorldScene>? scenes,
}) => MaterialApp(
  home: MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: Scaffold(
      body: RepaintBoundary(
        key: const ValueKey<String>('golden'),
        child: ScrollWorldView(
          scenes: scenes ?? goldenScenes(),
          scrollController: controller,
        ),
      ),
    ),
  ),
);

void main() {
  final previousGoldenComparator = goldenFileComparator;
  final localTestFile = File('test/golden_test.dart');
  final testFile = localTestFile.existsSync()
      ? localTestFile
      : File('packages/scroll_world/test/golden_test.dart');
  goldenFileComparator = _TolerantGoldenFileComparator(
    testFile.absolute.uri,
    precisionTolerance: _goldenDiffTolerance,
  );
  tearDownAll(() => goldenFileComparator = previousGoldenComparator);

  testWidgets('mobile portrait', (tester) async {
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(goldenHost(ScrollController()));
    await tester.pump();
    await expectLater(
      find.byKey(const ValueKey<String>('golden')),
      matchesGoldenFile('goldens/mobile_portrait.png'),
    );
  });

  testWidgets('tablet', (tester) async {
    await setSurface(tester, const Size(800, 1000));
    await tester.pumpWidget(goldenHost(ScrollController()));
    await tester.pump();
    await expectLater(
      find.byKey(const ValueKey<String>('golden')),
      matchesGoldenFile('goldens/tablet.png'),
    );
  });

  testWidgets('desktop', (tester) async {
    await setSurface(tester, const Size(1440, 900));
    await tester.pumpWidget(goldenHost(ScrollController()));
    await tester.pump();
    await expectLater(
      find.byKey(const ValueKey<String>('golden')),
      matchesGoldenFile('goldens/desktop.png'),
    );
  });

  testWidgets('mid transition', (tester) async {
    await setSurface(tester, const Size(1200, 800));
    final controller = ScrollController();
    await tester.pumpWidget(goldenHost(controller));
    await tester.pump();
    controller.jumpTo(1.65 * 800);
    await tester.pump();
    await expectLater(
      find.byKey(const ValueKey<String>('golden')),
      matchesGoldenFile('goldens/mid_transition.png'),
    );
  });

  testWidgets('reduced motion final scene', (tester) async {
    await setSurface(tester, const Size(390, 844));
    final controller = ScrollController();
    await tester.pumpWidget(goldenHost(controller));
    await tester.pump();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    await expectLater(
      find.byKey(const ValueKey<String>('golden')),
      matchesGoldenFile('goldens/reduced_motion_final.png'),
    );
  });

  testWidgets('poster failure fallback', (tester) async {
    await setSurface(tester, const Size(800, 600));
    final failedScene = ScrollWorldScene(
      id: 'failure',
      title: 'The story remains available',
      description: 'Playback failures never create a blank experience.',
      sources: const ScrollWorldSources(
        webStandard: ScrollWorldSource.asset('missing.mp4'),
      ),
      poster: const AssetImage('missing.webp'),
      transitionExtent: 0,
    );
    await tester.pumpWidget(
      goldenHost(ScrollController(), scenes: <ScrollWorldScene>[failedScene]),
    );
    await tester.pump();
    await expectLater(
      find.byKey(const ValueKey<String>('golden')),
      matchesGoldenFile('goldens/error_fallback.png'),
    );
  });
}

final class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  }) : assert(
         precisionTolerance >= 0 && precisionTolerance <= 1,
         'precisionTolerance must be between 0 and 1',
       ),
       _precisionTolerance = precisionTolerance;

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    final passed = result.passed || result.diffPercent <= _precisionTolerance;
    if (passed) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
