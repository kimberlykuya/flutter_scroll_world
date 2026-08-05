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

enum ScrollWorldDirection { stationary, forward, reverse }

/// Controls navigation and observes progress for one [ScrollWorldView].
final class ScrollWorldController extends ChangeNotifier {
  Future<void> Function(String, double, Duration?, Curve?)? _animateToScene;
  void Function(String, double)? _jumpToScene;
  Future<void> Function(Duration?, Curve?)? _replayReverse;
  void Function()? _cancelMotion;
  void Function(String)? _openGate;
  void Function(String)? _resetGate;
  bool Function(String)? _isGateOpen;
  double _overallProgress = 0;
  double _activeSceneProgress = 0;
  String? _activeSceneId;
  ScrollWorldMotionState _motionState = ScrollWorldMotionState.idle;
  ScrollWorldDirection _direction = ScrollWorldDirection.stationary;

  bool get isAttached => _replayReverse != null;
  double get overallProgress => _overallProgress;
  double get activeSceneProgress => _activeSceneProgress;
  String? get activeSceneId => _activeSceneId;
  ScrollWorldMotionState get motionState => _motionState;
  ScrollWorldDirection get direction => _direction;

  Future<void> animateToScene(
    String sceneId, {
    double sceneProgress = 0.5,
    Duration? duration,
    Curve? curve,
  }) {
    final callback = _animateToScene;
    if (callback == null) {
      throw StateError('ScrollWorldController is not attached to a view.');
    }
    return callback(sceneId, sceneProgress, duration, curve);
  }

  void jumpToScene(String sceneId, {double sceneProgress = 0.5}) {
    final callback = _jumpToScene;
    if (callback == null) {
      throw StateError('ScrollWorldController is not attached to a view.');
    }
    callback(sceneId, sceneProgress);
  }

  void openGate(String sceneId) {
    final callback = _openGate;
    if (callback == null) {
      throw StateError('ScrollWorldController is not attached to a view.');
    }
    callback(sceneId);
  }

  void resetGate(String sceneId) {
    final callback = _resetGate;
    if (callback == null) {
      throw StateError('ScrollWorldController is not attached to a view.');
    }
    callback(sceneId);
  }

  bool isGateOpen(String sceneId) => _isGateOpen?.call(sceneId) ?? false;

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
    required Future<void> Function(String, double, Duration?, Curve?)
    animateToScene,
    required void Function(String, double) jumpToScene,
    required Future<void> Function(Duration?, Curve?) replayReverse,
    required void Function() cancelMotion,
    required void Function(String) openGate,
    required void Function(String) resetGate,
    required bool Function(String) isGateOpen,
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
    _openGate = openGate;
    _resetGate = resetGate;
    _isGateOpen = isGateOpen;
  }

  @internal
  void update({
    required double overallProgress,
    required double activeSceneProgress,
    required String? activeSceneId,
    required ScrollWorldMotionState motionState,
    required ScrollWorldDirection direction,
  }) {
    final changed =
        _overallProgress != overallProgress ||
        _activeSceneProgress != activeSceneProgress ||
        _activeSceneId != activeSceneId ||
        _motionState != motionState ||
        _direction != direction;
    _overallProgress = overallProgress;
    _activeSceneProgress = activeSceneProgress;
    _activeSceneId = activeSceneId;
    _motionState = motionState;
    _direction = direction;
    if (changed) notifyListeners();
  }

  @internal
  void detach() {
    _animateToScene = null;
    _jumpToScene = null;
    _replayReverse = null;
    _cancelMotion = null;
    _openGate = null;
    _resetGate = null;
    _isGateOpen = null;
    _motionState = ScrollWorldMotionState.idle;
    _direction = ScrollWorldDirection.stationary;
  }
}
