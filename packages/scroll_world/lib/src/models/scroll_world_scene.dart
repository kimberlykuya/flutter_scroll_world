import 'package:flutter/widgets.dart';

import 'scroll_world_source.dart';
import 'scroll_world_action.dart';

enum ScrollWorldOverlayAnimation { none, fade, fadeSlide }

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
}
