import 'package:flutter/foundation.dart';

import '../controllers/scroll_world_controller.dart';
import 'scroll_world_scene.dart';

/// The current render and interaction state for one active scene.
@immutable
final class ScrollWorldSceneFrame {
  const ScrollWorldSceneFrame({
    required this.scene,
    required this.sceneIndex,
    required this.rawProgress,
    required this.mediaProgress,
    required this.visibility,
    required this.overallProgress,
    required this.direction,
    required this.motionState,
    required this.reducedMotion,
  });

  final ScrollWorldScene scene;
  final int sceneIndex;
  final double rawProgress;
  final double mediaProgress;
  final double visibility;
  final double overallProgress;
  final ScrollWorldDirection direction;
  final ScrollWorldMotionState motionState;
  final bool reducedMotion;

  bool get isInteractive =>
      visibility >= 0.5 && scene.interactionRegion.contains(rawProgress);
}
