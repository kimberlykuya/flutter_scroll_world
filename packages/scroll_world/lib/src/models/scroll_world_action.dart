import 'package:flutter/foundation.dart';

/// The behavior executed by a [ScrollWorldAction].
enum ScrollWorldActionIntent { replayReverse, navigateToScene, custom }

/// Visual emphasis for the built-in action renderer.
enum ScrollWorldActionStyle { primary, secondary }

/// A declarative, accessible action shown with a scene's narrative content.
@immutable
final class ScrollWorldAction {
  const ScrollWorldAction.replayReverse({
    required this.id,
    required this.label,
    this.semanticLabel,
    this.style = ScrollWorldActionStyle.primary,
  }) : intent = ScrollWorldActionIntent.replayReverse,
       targetSceneId = null;

  const ScrollWorldAction.navigateToScene({
    required this.id,
    required this.label,
    required this.targetSceneId,
    this.semanticLabel,
    this.style = ScrollWorldActionStyle.primary,
  }) : intent = ScrollWorldActionIntent.navigateToScene;

  const ScrollWorldAction.custom({
    required this.id,
    required this.label,
    this.semanticLabel,
    this.style = ScrollWorldActionStyle.secondary,
  }) : intent = ScrollWorldActionIntent.custom,
       targetSceneId = null;

  final String id;
  final String label;
  final String? semanticLabel;
  final ScrollWorldActionIntent intent;
  final ScrollWorldActionStyle style;
  final String? targetSceneId;
}
