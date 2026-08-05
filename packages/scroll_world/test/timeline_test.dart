import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_world/scroll_world.dart';
import 'package:scroll_world/src/models/scroll_world_timeline.dart';

const source = ScrollWorldSource.asset('scene.mp4');

ScrollWorldScene scene(
  String id, {
  double scrollExtent = 1,
  double transitionExtent = 0.5,
  bool connector = false,
  double linger = 0,
  ScrollWorldInteractionRegion interactionRegion =
      const ScrollWorldInteractionRegion(),
  double? gateAt,
  List<ScrollWorldAction> actions = const <ScrollWorldAction>[],
}) => ScrollWorldScene(
  id: id,
  sources: const ScrollWorldSources(webStandard: source),
  poster: const AssetImage('poster.webp'),
  scrollExtent: scrollExtent,
  transitionExtent: transitionExtent,
  connectorToNext: connector
      ? const ScrollWorldSources(webStandard: source)
      : null,
  linger: linger,
  interactionRegion: interactionRegion,
  gateAt: gateAt,
  actions: actions,
);

void main() {
  group('ScrollWorldTimeline', () {
    test('compiles scene and transition segments in viewport units', () {
      final timeline = ScrollWorldTimeline.compile(<ScrollWorldScene>[
        scene('one', connector: true),
        scene('two'),
        scene('three', transitionExtent: 0),
      ]);

      expect(timeline.segments, hasLength(5));
      expect(timeline.totalExtent, 4);
      expect(timeline.segments.map((segment) => segment.start), <double>[
        0,
        1,
        1.5,
        2.5,
        3,
      ]);
    });

    test('uses start-inclusive boundaries and clamps both directions', () {
      final timeline = ScrollWorldTimeline.compile(<ScrollWorldScene>[
        scene('one'),
        scene('two', transitionExtent: 0),
      ]);

      ScrollWorldFrame sample(double offset) => timeline.sampleAt(
        offset,
        transitionCurve: Curves.linear,
        seamFadeFraction: 0.12,
      );

      expect(sample(-10).activeSceneIndex, 0);
      expect(sample(1).segment.kind, ScrollWorldSegmentKind.transition);
      expect(sample(1.25).activeSceneIndex, 1);
      expect(sample(100).activeSceneIndex, 1);
      expect(sample(100).segmentProgress, 1);
    });

    test('samples the same scene order while travelling in reverse', () {
      final timeline = ScrollWorldTimeline.compile(<ScrollWorldScene>[
        scene('one'),
        scene('two'),
        scene('three', transitionExtent: 0),
      ]);

      final reverseOrder = <double>[4, 3.25, 2.75, 2, 1.25, 0.5, 0]
          .map(
            (offset) => timeline
                .sampleAt(
                  offset,
                  transitionCurve: Curves.linear,
                  seamFadeFraction: 0.12,
                )
                .activeSceneIndex,
          )
          .toList();

      expect(reverseOrder, <int>[2, 2, 2, 1, 1, 0, 0]);
    });

    test('crossfades directly when a connector is unavailable', () {
      final timeline = ScrollWorldTimeline.compile(<ScrollWorldScene>[
        scene('one'),
        scene('two', transitionExtent: 0),
      ]);
      final frame = timeline.sampleAt(
        1.25,
        transitionCurve: Curves.linear,
        seamFadeFraction: 0.12,
      );

      expect(frame.layers, hasLength(2));
      expect(frame.layers[0].opacity, 0.5);
      expect(frame.layers[1].opacity, 0.5);
    });

    test('uses no more than two layers at connector seams', () {
      final timeline = ScrollWorldTimeline.compile(<ScrollWorldScene>[
        scene('one', connector: true),
        scene('two', transitionExtent: 0),
      ]);

      for (final offset in <double>[1.01, 1.25, 1.49]) {
        final frame = timeline.sampleAt(
          offset,
          transitionCurve: Curves.linear,
          seamFadeFraction: 0.12,
        );
        expect(frame.layers.length, lessThanOrEqualTo(2));
      }
    });

    test('rejects invalid configuration', () {
      expect(
        () => ScrollWorldTimeline.compile(<ScrollWorldScene>[
          scene('same'),
          scene('same', transitionExtent: 0),
        ]),
        throwsArgumentError,
      );
      expect(
        () => ScrollWorldTimeline.compile(<ScrollWorldScene>[
          scene('zero', scrollExtent: 0, transitionExtent: 0),
        ]),
        throwsArgumentError,
      );
      expect(
        () => ScrollWorldTimeline.compile(<ScrollWorldScene>[
          scene('last', connector: true),
        ]),
        throwsArgumentError,
      );
    });

    test('overlay visibility keeps first and last narrative beats', () {
      expect(
        ScrollWorldTimeline.overlayVisibility(
          sceneIndex: 0,
          sceneCount: 3,
          sceneProgress: 0,
        ),
        1,
      );
      expect(
        ScrollWorldTimeline.overlayVisibility(
          sceneIndex: 1,
          sceneCount: 3,
          sceneProgress: 0.5,
        ),
        1,
      );
      expect(
        ScrollWorldTimeline.overlayVisibility(
          sceneIndex: 2,
          sceneCount: 3,
          sceneProgress: 1,
        ),
        1,
      );
    });

    test('linger slows the midpoint while preserving endpoints', () {
      expect(ScrollWorldTimeline.lingerProgress(0, 0.45), 0);
      expect(ScrollWorldTimeline.lingerProgress(0.5, 0.45), 0.5);
      expect(ScrollWorldTimeline.lingerProgress(1, 0.45), 1);
      expect(ScrollWorldTimeline.lingerProgress(0.4, 0.45), greaterThan(0.4));
      expect(ScrollWorldTimeline.lingerProgress(0.6, 0.45), lessThan(0.6));
    });

    test('validates action IDs and navigation targets', () {
      expect(
        () => ScrollWorldTimeline.compile(<ScrollWorldScene>[
          scene(
            'one',
            transitionExtent: 0,
            actions: const <ScrollWorldAction>[
              ScrollWorldAction.navigateToScene(
                id: 'next',
                label: 'Next',
                targetSceneId: 'missing',
              ),
            ],
          ),
        ]),
        throwsArgumentError,
      );
      expect(
        () => ScrollWorldTimeline.compile(<ScrollWorldScene>[
          scene('one', transitionExtent: 0, linger: 0.7),
        ]),
        throwsArgumentError,
      );
    });

    test('maps explicit scene progress and validates interaction gates', () {
      final timeline = ScrollWorldTimeline.compile(<ScrollWorldScene>[
        scene('one', scrollExtent: 2, gateAt: 0.6),
        scene('two', scrollExtent: 3, transitionExtent: 0),
      ]);

      expect(timeline.sceneOffset(0, progress: 0), 0);
      expect(timeline.sceneOffset(0, progress: 0.6), 1.2);
      expect(timeline.sceneOffset(1, progress: 0.25), 3.25);
      expect(
        () => ScrollWorldTimeline.compile(<ScrollWorldScene>[
          scene('bad', gateAt: 1, transitionExtent: 0),
        ]),
        throwsArgumentError,
      );
      expect(
        () => ScrollWorldTimeline.compile(<ScrollWorldScene>[
          scene(
            'bad-region',
            transitionExtent: 0,
            interactionRegion: const ScrollWorldInteractionRegion(
              start: 0.8,
              end: 0.4,
            ),
          ),
        ]),
        throwsArgumentError,
      );
    });
  });
}
