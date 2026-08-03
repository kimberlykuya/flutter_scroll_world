import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// The source of the journey's current movement.
enum ScrollWorldMotionState {
  idle,
  userScrolling,
  navigating,
  replayingReverse,
}

/// Controls navigation and observes progress for one [ScrollWorldView].
final class ScrollWorldController extends ChangeNotifier {
  Future<void> Function(String, Duration?, Curve?)? _animateToScene;
  void Function(String)? _jumpToScene;
  Future<void> Function(Duration?, Curve?)? _replayReverse;
  void Function()? _cancelMotion;
  double _overallProgress = 0;
  String? _activeSceneId;
  ScrollWorldMotionState _motionState = ScrollWorldMotionState.idle;

  bool get isAttached => _replayReverse != null;
  double get overallProgress => _overallProgress;
  String? get activeSceneId => _activeSceneId;
  ScrollWorldMotionState get motionState => _motionState;

  Future<void> animateToScene(
    String sceneId, {
    Duration? duration,
    Curve? curve,
  }) {
    final callback = _animateToScene;
    if (callback == null) {
      throw StateError('ScrollWorldController is not attached to a view.');
    }
    return callback(sceneId, duration, curve);
  }

  void jumpToScene(String sceneId) {
    final callback = _jumpToScene;
    if (callback == null) {
      throw StateError('ScrollWorldController is not attached to a view.');
    }
    callback(sceneId);
  }

  Future<void> replayReverse({Duration? duration, Curve? curve}) {
    final callback = _replayReverse;
    if (callback == null) {
      throw StateError('ScrollWorldController is not attached to a view.');
    }
    return callback(duration, curve);
  }

  void cancelMotion() => _cancelMotion?.call();

  @internal
  void attach({
    required Future<void> Function(String, Duration?, Curve?) animateToScene,
    required void Function(String) jumpToScene,
    required Future<void> Function(Duration?, Curve?) replayReverse,
    required void Function() cancelMotion,
  }) {
    if (isAttached) {
      throw StateError(
        'A ScrollWorldController can only be attached to one view at a time.',
      );
    }
    _animateToScene = animateToScene;
    _jumpToScene = jumpToScene;
    _replayReverse = replayReverse;
    _cancelMotion = cancelMotion;
  }

  @internal
  void update({
    required double overallProgress,
    required String? activeSceneId,
    required ScrollWorldMotionState motionState,
  }) {
    final changed =
        _overallProgress != overallProgress ||
        _activeSceneId != activeSceneId ||
        _motionState != motionState;
    _overallProgress = overallProgress;
    _activeSceneId = activeSceneId;
    _motionState = motionState;
    if (changed) notifyListeners();
  }

  @internal
  void detach() {
    _animateToScene = null;
    _jumpToScene = null;
    _replayReverse = null;
    _cancelMotion = null;
    _motionState = ScrollWorldMotionState.idle;
  }
}
