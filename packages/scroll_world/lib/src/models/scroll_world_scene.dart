import 'package:flutter/widgets.dart';

import 'scroll_world_source.dart';
import 'scroll_world_action.dart';

enum ScrollWorldOverlayAnimation { none, fade, fadeSlide }

/// The part of a scene during which its live content can receive input.
@immutable
final class ScrollWorldInteractionRegion {
  const ScrollWorldInteractionRegion({this.start = 0, this.end = 1});

  final double start;
  final double end;

  bool contains(double progress) => progress >= start && progress <= end;

  void validate(String sceneId) {
    if (!start.isFinite ||
        !end.isFinite ||
        start < 0 ||
        end > 1 ||
        start > end) {
      throw ArgumentError.value(
        this,
        'scene.interactionRegion',
        '$sceneId must use a finite range between zero and one',
      );
    }
  }
}

/// Declarative content and media for one stop in a scroll world.
@immutable
final class ScrollWorldScene {
  const ScrollWorldScene({
    required this.id,
    required this.sources,
    required this.poster,
    this.title,
    this.description,
    this.scrollExtent = 1.4,
    this.transitionExtent = 0.2,
    this.overlayAlignment = Alignment.bottomLeft,
    this.overlayAnimation = ScrollWorldOverlayAnimation.fadeSlide,
    this.connectorToNext,
    this.reducedMotionImage,
    this.linger = 0,
    this.actions = const <ScrollWorldAction>[],
    this.interactionRegion = const ScrollWorldInteractionRegion(),
    this.gateAt,
  });

  final String id;
  final ScrollWorldSources sources;
  final ImageProvider<Object> poster;
  final String? title;
  final String? description;
  final double scrollExtent;
  final double transitionExtent;
  final Alignment overlayAlignment;
  final ScrollWorldOverlayAnimation overlayAnimation;
  final ScrollWorldSources? connectorToNext;
  final ImageProvider<Object>? reducedMotionImage;

  /// Slows media progress around the scene midpoint without changing endpoints.
  final double linger;
  final List<ScrollWorldAction> actions;

  /// Controls when full-stage scene content can receive pointer input.
  final ScrollWorldInteractionRegion interactionRegion;

  /// Stops forward scrolling at this normalized scene progress until opened.
  final double? gateAt;
}
