import 'dart:math' as math;

import 'package:flutter/foundation.dart';

enum PadloWorldMotionState { idle, dragging, settling, replaying, blocked }

final class PadloWorldChapter {
  const PadloWorldChapter({
    required this.id,
    required this.title,
    required this.description,
    required this.start,
    required this.end,
    this.routeAnchor = '',
    this.gateAt,
    this.reducedMotionProgress,
  }) : assert(start >= 0 && end <= 1 && end > start),
       assert(gateAt == null || (gateAt > start && gateAt <= end));

  final String id;
  final String title;
  final String description;
  final double start;
  final double end;
  final String routeAnchor;
  final double? gateAt;
  final double? reducedMotionProgress;

  bool contains(double progress) =>
      progress >= start && (progress < end || (end == 1 && progress == 1));

  double localProgress(double progress) =>
      ((progress - start) / (end - start)).clamp(0.0, 1.0).toDouble();
}

final class PadloWorldTimeline {
  const PadloWorldTimeline({this.extentFactor = 8.0});

  final double extentFactor;

  static const _defaultChapters = <PadloWorldChapter>[
    PadloWorldChapter(
      id: 'first-serve',
      title: 'First serve',
      description:
          'Follow the ball into a Ljubljana night session and see the court as a positioning map.',
      start: 0,
      end: 0.32,
      routeAnchor: '/onboarding',
    ),
    PadloWorldChapter(
      id: 'positioning-lab',
      title: 'Positioning lab',
      description:
          'Choose the pressure zone that keeps Luka and Nika connected to the net.',
      start: 0.32,
      end: 0.68,
      routeAnchor: '/positioning-lab',
      gateAt: 0.60,
      reducedMotionProgress: 0.50,
    ),
    PadloWorldChapter(
      id: 'decision-gate',
      title: 'Decision gate',
      description:
          'Read the next ball. Attack, hold, or recover before the point turns.',
      start: 0.68,
      end: 1,
      routeAnchor: '/decision-gate',
      gateAt: 0.92,
      reducedMotionProgress: 0.82,
    ),
  ];

  List<PadloWorldChapter> get chapters => _defaultChapters;

  PadloWorldChapter chapterAt(double progress) {
    final value = progress.clamp(0.0, 1.0).toDouble();
    for (final chapter in chapters) {
      if (chapter.contains(value)) return chapter;
    }
    return chapters.last;
  }

  double clampProgress(double progress, {required Set<String> releasedGates}) {
    var value = progress.clamp(0.0, 1.0).toDouble();
    for (final chapter in chapters) {
      final gate = chapter.gateAt;
      if (gate == null || releasedGates.contains(chapter.id)) continue;
      if (value > gate && value >= chapter.start) value = gate;
    }
    return value;
  }

  double offsetForProgress(double progress, double viewportHeight) {
    if (viewportHeight <= 0) return 0;
    return progress.clamp(0.0, 1.0).toDouble() *
        viewportHeight *
        (extentFactor - 1);
  }

  double progressForOffset(double offset, double viewportHeight) {
    if (viewportHeight <= 0) return 0;
    return (offset / (viewportHeight * (extentFactor - 1)))
        .clamp(0.0, 1.0)
        .toDouble();
  }
}

final class PadloWorldController extends ChangeNotifier {
  PadloWorldController({this.timeline = const PadloWorldTimeline()});

  final PadloWorldTimeline timeline;
  final Set<String> _releasedGates = <String>{};
  double _rawProgress = 0;
  double _renderedProgress = 0;
  double _replayElapsed = 0;
  double _replayDuration = 10;
  double _replayStartProgress = 0;
  PadloWorldMotionState _motionState = PadloWorldMotionState.idle;
  bool _disposed = false;

  double get rawProgress => _rawProgress;
  double get renderedProgress => _renderedProgress;
  PadloWorldChapter get activeChapter => timeline.chapterAt(_renderedProgress);
  double get activeChapterProgress =>
      activeChapter.localProgress(_renderedProgress);
  PadloWorldMotionState get motionState => _motionState;
  Set<String> get releasedGates => Set.unmodifiable(_releasedGates);
  bool get isReplaying => _motionState == PadloWorldMotionState.replaying;
  bool get isGateBlocked => _motionState == PadloWorldMotionState.blocked;

  bool isGateReleased(String chapterId) => _releasedGates.contains(chapterId);

  void navigateToChapter(String chapterId, {double sceneProgress = 0.5}) {
    navigateToChapterProgress(chapterId, sceneProgress: sceneProgress);
  }

  void navigateToChapterProgress(
    String chapterId, {
    required double sceneProgress,
  }) {
    final chapter = timeline.chapters.firstWhere(
      (candidate) => candidate.id == chapterId,
      orElse: () => throw ArgumentError.value(chapterId, 'chapterId'),
    );
    final local = sceneProgress.clamp(0.0, 1.0).toDouble();
    jumpToProgress(chapter.start + (chapter.end - chapter.start) * local);
  }

  void setRawProgress(double value, {bool userInitiated = true}) {
    if (_disposed) return;
    if (userInitiated) cancelMotion();
    final clamped = timeline.clampProgress(
      value,
      releasedGates: _releasedGates,
    );
    final requested = value.clamp(0.0, 1.0).toDouble();
    final blocked = requested > clamped + 0.0001;
    _rawProgress = clamped;
    _motionState = blocked
        ? PadloWorldMotionState.blocked
        : (userInitiated
              ? PadloWorldMotionState.dragging
              : PadloWorldMotionState.settling);
    notifyListeners();
  }

  void setRenderedProgressForTesting(double value) {
    _renderedProgress = value.clamp(0.0, 1.0).toDouble();
    notifyListeners();
  }

  void releaseGate(String chapterId) {
    if (_disposed) return;
    final chapter = timeline.chapters.firstWhere(
      (candidate) => candidate.id == chapterId,
      orElse: () => throw ArgumentError.value(chapterId, 'chapterId'),
    );
    _releasedGates.add(chapter.id);
    final gate = chapter.gateAt;
    if (gate != null && _rawProgress <= gate) {
      _rawProgress = (gate + 0.002).clamp(0.0, 1.0).toDouble();
    }
    _motionState = PadloWorldMotionState.settling;
    notifyListeners();
  }

  void resetGate(String chapterId) {
    _releasedGates.remove(chapterId);
    notifyListeners();
  }

  void jumpToProgress(double progress) {
    setRawProgress(progress, userInitiated: false);
    _renderedProgress = _rawProgress;
    _motionState = PadloWorldMotionState.idle;
    notifyListeners();
  }

  void startReplay({Duration duration = const Duration(seconds: 10)}) {
    if (_disposed) return;
    _replayElapsed = 0;
    _replayDuration = math.max(duration.inMicroseconds / 1000000, 0.001);
    _replayStartProgress = _renderedProgress;
    _motionState = PadloWorldMotionState.replaying;
    notifyListeners();
  }

  void cancelMotion() {
    if (_motionState == PadloWorldMotionState.replaying ||
        _motionState == PadloWorldMotionState.settling) {
      _motionState = PadloWorldMotionState.dragging;
      notifyListeners();
    }
  }

  void cancelTravel() => cancelMotion();

  void tick(double deltaSeconds, {bool reducedMotion = false}) {
    if (_disposed || deltaSeconds <= 0) return;
    if (isReplaying) {
      _replayElapsed = (_replayElapsed + deltaSeconds)
          .clamp(0.0, _replayDuration)
          .toDouble();
      final t = (_replayElapsed / _replayDuration).clamp(0.0, 1.0).toDouble();
      final eased = 0.5 - 0.5 * math.cos(t * math.pi);
      _rawProgress = (_replayStartProgress * (1 - eased))
          .clamp(0.0, 1.0)
          .toDouble();
      if (t >= 1) {
        _rawProgress = 0;
        _renderedProgress = 0;
        _motionState = PadloWorldMotionState.idle;
      }
    }
    final smoothing = reducedMotion
        ? 1.0
        : 1.0 - math.pow(0.82, deltaSeconds * 60).toDouble();
    _renderedProgress += (_rawProgress - _renderedProgress) * smoothing;
    if ((_renderedProgress - _rawProgress).abs() < 0.0005) {
      _renderedProgress = _rawProgress;
      if (_motionState == PadloWorldMotionState.dragging ||
          _motionState == PadloWorldMotionState.settling) {
        _motionState = PadloWorldMotionState.idle;
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
