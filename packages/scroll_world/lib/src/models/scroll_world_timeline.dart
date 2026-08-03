import 'dart:math' as math;

import 'package:flutter/animation.dart';

import 'scroll_world_scene.dart';

enum ScrollWorldSegmentKind { scene, transition }

enum ScrollWorldMediaKind { scene, connector }

final class ScrollWorldMediaKey {
  const ScrollWorldMediaKey.scene(this.index)
    : kind = ScrollWorldMediaKind.scene;
  const ScrollWorldMediaKey.connector(this.index)
    : kind = ScrollWorldMediaKind.connector;

  final ScrollWorldMediaKind kind;
  final int index;

  String get value => '${kind.name}:$index';

  @override
  bool operator ==(Object other) =>
      other is ScrollWorldMediaKey &&
      other.kind == kind &&
      other.index == index;

  @override
  int get hashCode => Object.hash(kind, index);
}

final class ScrollWorldSegment {
  const ScrollWorldSegment.scene({
    required this.index,
    required this.start,
    required this.extent,
    required this.sceneIndex,
    required this.linger,
  }) : kind = ScrollWorldSegmentKind.scene,
       nextSceneIndex = null,
       hasConnector = false;

  const ScrollWorldSegment.transition({
    required this.index,
    required this.start,
    required this.extent,
    required this.sceneIndex,
    required int this.nextSceneIndex,
    required this.hasConnector,
  }) : kind = ScrollWorldSegmentKind.transition,
       linger = 0;

  final int index;
  final ScrollWorldSegmentKind kind;
  final double start;
  final double extent;
  final int sceneIndex;
  final int? nextSceneIndex;
  final bool hasConnector;
  final double linger;

  double get end => start + extent;

  double rawProgressAt(double offset) =>
      extent == 0 ? 1 : ((offset - start) / extent).clamp(0.0, 1.0).toDouble();

  double mediaProgressAt(double offset) {
    final progress = rawProgressAt(offset);
    return kind == ScrollWorldSegmentKind.scene
        ? ScrollWorldTimeline.lingerProgress(progress, linger)
        : progress;
  }

  ScrollWorldMediaKey? get ownMediaKey => switch (kind) {
    ScrollWorldSegmentKind.scene => ScrollWorldMediaKey.scene(sceneIndex),
    ScrollWorldSegmentKind.transition when hasConnector =>
      ScrollWorldMediaKey.connector(sceneIndex),
    ScrollWorldSegmentKind.transition => null,
  };
}

final class ScrollWorldLayerFrame {
  const ScrollWorldLayerFrame({
    required this.mediaKey,
    required this.opacity,
    required this.progress,
  });

  final ScrollWorldMediaKey mediaKey;
  final double opacity;
  final double progress;
}

final class ScrollWorldFrame {
  const ScrollWorldFrame({
    required this.segment,
    required this.segmentProgress,
    required this.overallProgress,
    required this.activeSceneIndex,
    required this.layers,
  });

  final ScrollWorldSegment segment;
  final double segmentProgress;
  final double overallProgress;
  final int activeSceneIndex;
  final List<ScrollWorldLayerFrame> layers;
}

/// Pure mapping between logical viewport scroll units and render state.
final class ScrollWorldTimeline {
  ScrollWorldTimeline._(this.scenes, this.segments, this.totalExtent);

  factory ScrollWorldTimeline.compile(List<ScrollWorldScene> scenes) {
    final ids = <String>{};
    final segments = <ScrollWorldSegment>[];
    var offset = 0.0;

    for (var index = 0; index < scenes.length; index++) {
      final scene = scenes[index];
      if (scene.id.trim().isEmpty) {
        throw ArgumentError.value(scene.id, 'scene.id', 'must not be blank');
      }
      if (!ids.add(scene.id)) {
        throw ArgumentError.value(scene.id, 'scene.id', 'must be unique');
      }
      if (scene.sources.isEmpty) {
        throw ArgumentError.value(
          scene.id,
          'scene.sources',
          'must not be empty',
        );
      }
      if (!scene.scrollExtent.isFinite || scene.scrollExtent <= 0) {
        throw ArgumentError.value(
          scene.scrollExtent,
          'scene.scrollExtent',
          'must be finite and greater than zero',
        );
      }
      if (!scene.linger.isFinite || scene.linger < 0 || scene.linger > 0.6) {
        throw ArgumentError.value(
          scene.linger,
          'scene.linger',
          'must be between zero and 0.6',
        );
      }
      final actionIds = <String>{};
      for (final action in scene.actions) {
        if (action.id.trim().isEmpty || action.label.trim().isEmpty) {
          throw ArgumentError.value(
            action.id,
            'scene.actions',
            'action IDs and labels must not be blank',
          );
        }
        if (!actionIds.add(action.id)) {
          throw ArgumentError.value(
            action.id,
            'scene.actions',
            'action IDs must be unique within a scene',
          );
        }
        if (action.targetSceneId case final target?
            when !scenes.any((candidate) => candidate.id == target)) {
          throw ArgumentError.value(
            target,
            'action.targetSceneId',
            'must identify a scene in this Scroll World',
          );
        }
      }
      if (!scene.transitionExtent.isFinite || scene.transitionExtent < 0) {
        throw ArgumentError.value(
          scene.transitionExtent,
          'scene.transitionExtent',
          'must be finite and non-negative',
        );
      }
      if (scene.connectorToNext?.isEmpty ?? false) {
        throw ArgumentError.value(
          scene.id,
          'scene.connectorToNext',
          'must contain at least one source',
        );
      }
      if (index == scenes.length - 1 && scene.connectorToNext != null) {
        throw ArgumentError.value(
          scene.id,
          'scene.connectorToNext',
          'the final scene cannot have a connector',
        );
      }
      if (scene.connectorToNext != null && scene.transitionExtent == 0) {
        throw ArgumentError.value(
          scene.id,
          'scene.transitionExtent',
          'must be greater than zero when a connector is configured',
        );
      }

      segments.add(
        ScrollWorldSegment.scene(
          index: segments.length,
          start: offset,
          extent: scene.scrollExtent,
          sceneIndex: index,
          linger: scene.linger,
        ),
      );
      offset += scene.scrollExtent;

      if (index < scenes.length - 1 && scene.transitionExtent > 0) {
        segments.add(
          ScrollWorldSegment.transition(
            index: segments.length,
            start: offset,
            extent: scene.transitionExtent,
            sceneIndex: index,
            nextSceneIndex: index + 1,
            hasConnector: scene.connectorToNext != null,
          ),
        );
        offset += scene.transitionExtent;
      }
    }

    return ScrollWorldTimeline._(
      List<ScrollWorldScene>.unmodifiable(scenes),
      List<ScrollWorldSegment>.unmodifiable(segments),
      offset,
    );
  }

  final List<ScrollWorldScene> scenes;
  final List<ScrollWorldSegment> segments;
  final double totalExtent;

  ScrollWorldFrame sampleAt(
    double offset, {
    required Curve transitionCurve,
    required double seamFadeFraction,
    bool useConnectors = true,
  }) {
    if (segments.isEmpty) {
      throw StateError('Cannot sample an empty Scroll World timeline.');
    }
    final clampedOffset = offset.clamp(0.0, totalExtent).toDouble();
    var segment = segments.last;
    for (final candidate in segments) {
      if (clampedOffset < candidate.end || candidate == segments.last) {
        segment = candidate;
        break;
      }
    }
    final progress = segment.rawProgressAt(clampedOffset);
    final overall = totalExtent == 0 ? 0.0 : clampedOffset / totalExtent;

    if (segment.kind == ScrollWorldSegmentKind.scene) {
      final mediaProgress = segment.mediaProgressAt(clampedOffset);
      return ScrollWorldFrame(
        segment: segment,
        segmentProgress: progress,
        overallProgress: overall,
        activeSceneIndex: segment.sceneIndex,
        layers: <ScrollWorldLayerFrame>[
          ScrollWorldLayerFrame(
            mediaKey: ScrollWorldMediaKey.scene(segment.sceneIndex),
            opacity: 1,
            progress: mediaProgress,
          ),
        ],
      );
    }

    final eased = transitionCurve.transform(progress);
    final nextIndex = segment.nextSceneIndex!;
    final activeIndex = progress < 0.5 ? segment.sceneIndex : nextIndex;
    final layers = <ScrollWorldLayerFrame>[];
    if (segment.hasConnector && useConnectors) {
      final edge = seamFadeFraction.clamp(0.01, 0.49).toDouble();
      if (progress < edge) {
        final blend = transitionCurve.transform(progress / edge);
        layers
          ..add(
            ScrollWorldLayerFrame(
              mediaKey: ScrollWorldMediaKey.scene(segment.sceneIndex),
              opacity: 1 - blend,
              progress: 1,
            ),
          )
          ..add(
            ScrollWorldLayerFrame(
              mediaKey: ScrollWorldMediaKey.connector(segment.sceneIndex),
              opacity: blend,
              progress: progress,
            ),
          );
      } else if (progress > 1 - edge) {
        final blend = transitionCurve.transform((progress - (1 - edge)) / edge);
        layers
          ..add(
            ScrollWorldLayerFrame(
              mediaKey: ScrollWorldMediaKey.connector(segment.sceneIndex),
              opacity: 1 - blend,
              progress: progress,
            ),
          )
          ..add(
            ScrollWorldLayerFrame(
              mediaKey: ScrollWorldMediaKey.scene(nextIndex),
              opacity: blend,
              progress: 0,
            ),
          );
      } else {
        layers.add(
          ScrollWorldLayerFrame(
            mediaKey: ScrollWorldMediaKey.connector(segment.sceneIndex),
            opacity: 1,
            progress: progress,
          ),
        );
      }
    } else {
      layers
        ..add(
          ScrollWorldLayerFrame(
            mediaKey: ScrollWorldMediaKey.scene(segment.sceneIndex),
            opacity: 1 - eased,
            progress: 1,
          ),
        )
        ..add(
          ScrollWorldLayerFrame(
            mediaKey: ScrollWorldMediaKey.scene(nextIndex),
            opacity: eased,
            progress: 0,
          ),
        );
    }

    return ScrollWorldFrame(
      segment: segment,
      segmentProgress: progress,
      overallProgress: overall,
      activeSceneIndex: activeIndex,
      layers: List<ScrollWorldLayerFrame>.unmodifiable(layers),
    );
  }

  ScrollWorldSegment sceneSegment(int sceneIndex) => segments.firstWhere(
    (segment) =>
        segment.kind == ScrollWorldSegmentKind.scene &&
        segment.sceneIndex == sceneIndex,
  );

  double sceneMidpoint(int sceneIndex) {
    final segment = sceneSegment(sceneIndex);
    return segment.start + segment.extent / 2;
  }

  static double lingerProgress(double progress, double linger) {
    final value = progress.clamp(0.0, 1.0).toDouble();
    final strength = linger.clamp(0.0, 0.6).toDouble();
    final centered = value - 0.5;
    return (1 - strength) * value +
        strength * (4 * centered * centered * centered + 0.5);
  }

  static double overlayVisibility({
    required int sceneIndex,
    required int sceneCount,
    required double sceneProgress,
  }) {
    final progress = sceneProgress.clamp(0.0, 1.0).toDouble();
    if (sceneIndex == 0) {
      return 1 - _smooth((progress / 0.62).clamp(0.0, 1.0).toDouble());
    }
    if (sceneIndex == sceneCount - 1) {
      return _smooth((progress / 0.4).clamp(0.0, 1.0).toDouble());
    }
    return _smooth(
      (1 - (progress - 0.5).abs() / 0.5).clamp(0.0, 1.0).toDouble(),
    );
  }

  static double _smooth(double value) =>
      math.pow(value, 2).toDouble() * (3 - 2 * value);
}
