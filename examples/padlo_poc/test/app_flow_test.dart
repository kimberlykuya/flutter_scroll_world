import 'package:flutter_test/flutter_test.dart';
import 'package:padlo_poc/src/world/padlo_world_timeline.dart';

void main() {
  group('Padlo real-time world timeline', () {
    const timeline = PadloWorldTimeline();

    test('chapters have contiguous inclusive/exclusive boundaries', () {
      expect(timeline.chapterAt(0).id, 'first-serve');
      expect(timeline.chapterAt(0.32).id, 'positioning-lab');
      expect(timeline.chapterAt(0.68).id, 'decision-gate');
      expect(timeline.chapterAt(1).id, 'decision-gate');
      expect(timeline.chapters[1].routeAnchor, '/positioning-lab');
    });

    test('offset and progress mapping round trips', () {
      for (final progress in <double>[0, 0.18, 0.5, 0.82, 1]) {
        final offset = timeline.offsetForProgress(progress, 800);
        expect(
          timeline.progressForOffset(offset, 800),
          closeTo(progress, 0.0001),
        );
      }
    });

    test(
      'unreleased gates clamp forward progress but allow reverse travel',
      () {
        expect(
          timeline.clampProgress(0.9, releasedGates: const <String>{}),
          closeTo(0.6, 0.0001),
        );
        expect(
          timeline.clampProgress(0.4, releasedGates: const <String>{}),
          closeTo(0.4, 0.0001),
        );
      },
    );
  });

  group('Padlo world controller', () {
    test('latest scroll target wins and smoothing converges', () {
      final controller = PadloWorldController();
      controller.setRawProgress(0.25);
      controller.setRawProgress(0.4);
      expect(controller.rawProgress, closeTo(0.4, 0.0001));
      for (var i = 0; i < 60; i++) {
        controller.tick(1 / 60);
      }
      expect(controller.renderedProgress, closeTo(0.4, 0.001));
      controller.dispose();
    });

    test('correct gate release resumes the journey', () {
      final controller = PadloWorldController();
      controller.setRawProgress(0.85);
      expect(controller.isGateBlocked, isTrue);
      controller.releaseGate('positioning-lab');
      controller.releaseGate('decision-gate');
      controller.setRawProgress(0.85);
      expect(controller.rawProgress, closeTo(0.85, 0.001));
      controller.dispose();
    });

    test('chapter navigation resolves a bounded local progress', () {
      final controller = PadloWorldController();
      controller.releaseGate('positioning-lab');
      controller.navigateToChapter('positioning-lab', sceneProgress: 0.5);
      expect(controller.rawProgress, closeTo(0.5, 0.001));
      expect(controller.activeChapterProgress, closeTo(0.5, 0.001));
      controller.cancelTravel();
      controller.dispose();
    });

    test('reverse replay reaches zero and stops', () {
      final controller = PadloWorldController();
      controller.releaseGate('positioning-lab');
      controller.releaseGate('decision-gate');
      controller.setRawProgress(0.9);
      controller.setRenderedProgressForTesting(0.9);
      controller.startReplay(duration: const Duration(seconds: 2));
      for (var i = 0; i < 140; i++) {
        controller.tick(1 / 60);
      }
      expect(controller.rawProgress, closeTo(0, 0.001));
      expect(controller.renderedProgress, closeTo(0, 0.001));
      expect(controller.isReplaying, isFalse);
      controller.dispose();
    });
  });
}
