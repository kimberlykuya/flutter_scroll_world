import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_world/scroll_world.dart';

final class FakeDriverFactory implements ScrollVideoDriverFactory {
  int created = 0;
  int disposed = 0;

  @override
  ScrollVideoDriver create(ScrollWorldSource source) {
    created++;
    return FakeDriver(onDispose: () => disposed++);
  }
}

final class FakeDriver implements ScrollVideoDriver {
  FakeDriver({required this.onDispose});

  final VoidCallback onDispose;
  bool ready = false;

  @override
  Duration get duration => const Duration(seconds: 3);

  @override
  bool get isReady => ready;

  @override
  Widget buildView({BoxFit fit = BoxFit.cover}) => const ColoredBox(
    key: ValueKey<String>('fake-video'),
    color: Color(0xFF156F53),
  );

  @override
  Future<void> initialize() async => ready = true;

  @override
  Future<void> pause() async {}

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  Future<void> dispose() async => onDispose();
}

List<ScrollWorldScene> testScenes() => <ScrollWorldScene>[
  const ScrollWorldScene(
    id: 'one',
    title: 'Scene one',
    description: 'First scene',
    sources: ScrollWorldSources(
      webStandard: ScrollWorldSource.asset('one.mp4'),
    ),
    poster: AssetImage('missing-one.webp'),
    connectorToNext: ScrollWorldSources(
      webStandard: ScrollWorldSource.asset('connector.mp4'),
    ),
    transitionExtent: 0.5,
  ),
  const ScrollWorldScene(
    id: 'two',
    title: 'Scene two',
    description: 'Second scene',
    sources: ScrollWorldSources(
      webStandard: ScrollWorldSource.asset('two.mp4'),
    ),
    poster: AssetImage('missing-two.webp'),
    transitionExtent: 0,
    actions: <ScrollWorldAction>[
      ScrollWorldAction.replayReverse(
        id: 'replay',
        label: 'Replay the journey',
      ),
    ],
  ),
];

Widget host({required Widget child, bool disableAnimations = false}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(800, 600),
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('renders content and initializes a bounded nearby pool', (
    tester,
  ) async {
    final factory = FakeDriverFactory();
    ScrollWorldDriverDebugSnapshot? snapshot;
    await tester.pumpWidget(
      host(
        child: ScrollWorldView(
          scenes: testScenes(),
          driverFactory: factory,
          onDebugSnapshot: (value) => snapshot = value,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(find.text('Scene one'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('fake-video')), findsWidgets);
    expect(factory.created, lessThanOrEqualTo(3));
    expect(snapshot?.initializedCount, lessThanOrEqualTo(3));
  });

  testWidgets('reduced motion never creates a video driver', (tester) async {
    final factory = FakeDriverFactory();
    await tester.pumpWidget(
      host(
        disableAnimations: true,
        child: ScrollWorldView(scenes: testScenes(), driverFactory: factory),
      ),
    );
    await tester.pump();
    expect(factory.created, 0);
    expect(find.text('Scene one'), findsOneWidget);
  });

  testWidgets('navigation is labelled and changes scenes', (tester) async {
    final factory = FakeDriverFactory();
    var active = 'one';
    await tester.pumpWidget(
      host(
        child: ScrollWorldView(
          scenes: testScenes(),
          driverFactory: factory,
          onSceneChanged: (scene, index) => active = scene.id,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Scene two'));
    await tester.pumpAndSettle();

    expect(active, 'two');
    expect(find.text('Scene two'), findsOneWidget);
  });

  testWidgets('empty scenes use the supplied empty builder', (tester) async {
    await tester.pumpWidget(
      host(
        child: ScrollWorldView(
          scenes: const <ScrollWorldScene>[],
          emptyBuilder: (context) => const Text('Nothing here'),
        ),
      ),
    );
    expect(find.text('Nothing here'), findsOneWidget);
  });

  testWidgets('disposes drivers when removed', (tester) async {
    final factory = FakeDriverFactory();
    await tester.pumpWidget(
      host(
        child: ScrollWorldView(scenes: testScenes(), driverFactory: factory),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    expect(factory.disposed, factory.created);
  });

  testWidgets('final action remains visible and replays to the beginning', (
    tester,
  ) async {
    final factory = FakeDriverFactory();
    final scrollController = ScrollController();
    final journeyController = ScrollWorldController();
    final visited = <String>[];
    var actionCalls = 0;
    addTearDown(journeyController.dispose);
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      host(
        child: ScrollWorldView(
          scenes: testScenes(),
          driverFactory: factory,
          scrollController: scrollController,
          controller: journeyController,
          configuration: const ScrollWorldConfiguration(
            smoothingFactor: 1,
            reverseReplayDuration: Duration(milliseconds: 400),
          ),
          onSceneChanged: (scene, index) => visited.add(scene.id),
          onAction: (scene, action) => actionCalls += 1,
        ),
      ),
    );
    await tester.pump();
    scrollController.jumpTo(scrollController.position.maxScrollExtent);
    await tester.pump();

    expect(find.text('Replay the journey'), findsOneWidget);
    expect(find.bySemanticsLabel('Replay the journey'), findsOneWidget);
    expect(journeyController.activeSceneId, 'two');

    await tester.tap(find.text('Replay the journey'));
    await tester.pump();
    expect(
      journeyController.motionState,
      ScrollWorldMotionState.replayingReverse,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(scrollController.offset, greaterThan(0));
    expect(
      scrollController.offset,
      lessThan(scrollController.position.maxScrollExtent),
    );
    final replayButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Replay the journey'),
    );
    expect(replayButton.onPressed, isNull);
    await journeyController.replayReverse();
    expect(actionCalls, 1);
    await tester.pumpAndSettle();

    expect(scrollController.offset, closeTo(0, 0.01));
    expect(journeyController.activeSceneId, 'one');
    expect(journeyController.motionState, ScrollWorldMotionState.idle);
    expect(visited, containsAllInOrder(<String>['two', 'one']));
  });

  testWidgets('reduced motion replay resets immediately', (tester) async {
    final scrollController = ScrollController();
    final journeyController = ScrollWorldController();
    addTearDown(journeyController.dispose);
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      host(
        disableAnimations: true,
        child: ScrollWorldView(
          scenes: testScenes(),
          scrollController: scrollController,
          controller: journeyController,
        ),
      ),
    );
    await tester.pump();
    scrollController.jumpTo(scrollController.position.maxScrollExtent);
    await tester.pump();
    await tester.tap(find.text('Replay the journey'));
    await tester.pump();

    expect(scrollController.offset, closeTo(0, 0.01));
    expect(journeyController.activeSceneId, 'one');
  });

  testWidgets('keyboard input interrupts reverse replay', (tester) async {
    final scrollController = ScrollController();
    final journeyController = ScrollWorldController();
    addTearDown(journeyController.dispose);
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      host(
        child: ScrollWorldView(
          scenes: testScenes(),
          driverFactory: FakeDriverFactory(),
          scrollController: scrollController,
          controller: journeyController,
          configuration: const ScrollWorldConfiguration(
            smoothingFactor: 1,
            reverseReplayDuration: Duration(seconds: 5),
          ),
        ),
      ),
    );
    await tester.pump();
    scrollController.jumpTo(scrollController.position.maxScrollExtent);
    await tester.pump();
    await tester.tap(find.text('Replay the journey'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      journeyController.motionState,
      ScrollWorldMotionState.replayingReverse,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();

    expect(journeyController.motionState, ScrollWorldMotionState.idle);
    expect(scrollController.offset, closeTo(0, 0.01));
  });

  testWidgets('scene navigation actions use the public controller', (
    tester,
  ) async {
    final scrollController = ScrollController();
    final journeyController = ScrollWorldController();
    addTearDown(journeyController.dispose);
    addTearDown(scrollController.dispose);
    final scenes = <ScrollWorldScene>[
      const ScrollWorldScene(
        id: 'first',
        title: 'First',
        sources: ScrollWorldSources(
          webStandard: ScrollWorldSource.asset('first.mp4'),
        ),
        poster: AssetImage('missing-first.webp'),
        actions: <ScrollWorldAction>[
          ScrollWorldAction.navigateToScene(
            id: 'next',
            label: 'Continue to second',
            targetSceneId: 'second',
          ),
        ],
      ),
      const ScrollWorldScene(
        id: 'second',
        title: 'Second',
        sources: ScrollWorldSources(
          webStandard: ScrollWorldSource.asset('second.mp4'),
        ),
        poster: AssetImage('missing-second.webp'),
        transitionExtent: 0,
      ),
    ];
    await tester.pumpWidget(
      host(
        disableAnimations: true,
        child: ScrollWorldView(
          scenes: scenes,
          scrollController: scrollController,
          controller: journeyController,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Continue to second'));
    await tester.pump();

    expect(journeyController.activeSceneId, 'second');
    expect(scrollController.offset, greaterThan(0));
  });

  testWidgets('custom action builders call the host callback', (tester) async {
    ScrollWorldAction? tapped;
    final scenes = <ScrollWorldScene>[
      const ScrollWorldScene(
        id: 'custom',
        title: 'Choose a route',
        sources: ScrollWorldSources(
          webStandard: ScrollWorldSource.asset('custom.mp4'),
        ),
        poster: AssetImage('missing.webp'),
        transitionExtent: 0,
        actions: <ScrollWorldAction>[
          ScrollWorldAction.custom(id: 'continue', label: 'Continue'),
        ],
      ),
    ];
    await tester.pumpWidget(
      host(
        disableAnimations: true,
        child: ScrollWorldView(
          scenes: scenes,
          actionBuilder: (context, scene, action, onPressed) => TextButton(
            onPressed: onPressed,
            child: Text('Custom ${action.label}'),
          ),
          onAction: (scene, action) => tapped = action,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Custom Continue'), findsOneWidget);
    await tester.tap(find.text('Custom Continue'));
    await tester.pump();
    expect(tapped?.id, 'continue');
  });
}
