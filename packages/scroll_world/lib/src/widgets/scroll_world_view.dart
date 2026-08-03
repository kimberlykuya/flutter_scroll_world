import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../controllers/video_controller_pool.dart';
import '../controllers/scroll_progress_smoother.dart';
import '../controllers/scroll_world_controller.dart';
import '../models/scroll_world_action.dart';
import '../models/scroll_world_configuration.dart';
import '../models/scroll_world_error.dart';
import '../models/scroll_world_scene.dart';
import '../models/scroll_world_source.dart';
import '../models/scroll_world_theme.dart';
import '../models/scroll_world_timeline.dart';
import '../playback/scroll_video_driver.dart';
import '../playback/video_player_driver.dart';
import '../utilities/asset_selector.dart';

typedef ScrollWorldOverlayBuilder =
    Widget Function(
      BuildContext context,
      ScrollWorldScene scene,
      double sceneProgress,
      double visibility,
    );
typedef ScrollWorldSceneChangedCallback =
    void Function(ScrollWorldScene scene, int index);
typedef ScrollWorldActionCallback =
    FutureOr<void> Function(ScrollWorldScene scene, ScrollWorldAction action);
typedef ScrollWorldActionBuilder =
    Widget Function(
      BuildContext context,
      ScrollWorldScene scene,
      ScrollWorldAction action,
      VoidCallback? onPressed,
    );

/// A full-viewport, vertically scrollable video narrative.
final class ScrollWorldView extends StatefulWidget {
  const ScrollWorldView({
    required this.scenes,
    this.configuration = const ScrollWorldConfiguration(),
    this.theme = const ScrollWorldTheme(),
    this.scrollController,
    this.controller,
    this.driverFactory,
    this.overlayBuilder,
    this.actionBuilder,
    this.emptyBuilder,
    this.onSceneChanged,
    this.onLoadingChanged,
    this.onError,
    this.onDebugSnapshot,
    this.onAction,
    this.onMotionStateChanged,
    super.key,
  });

  final List<ScrollWorldScene> scenes;
  final ScrollWorldConfiguration configuration;
  final ScrollWorldTheme theme;
  final ScrollController? scrollController;
  final ScrollWorldController? controller;
  final ScrollVideoDriverFactory? driverFactory;
  final ScrollWorldOverlayBuilder? overlayBuilder;
  final ScrollWorldActionBuilder? actionBuilder;
  final WidgetBuilder? emptyBuilder;
  final ScrollWorldSceneChangedCallback? onSceneChanged;
  final ValueChanged<bool>? onLoadingChanged;
  final ScrollWorldErrorCallback? onError;
  final ValueChanged<ScrollWorldDriverDebugSnapshot>? onDebugSnapshot;
  final ScrollWorldActionCallback? onAction;
  final ValueChanged<ScrollWorldMotionState>? onMotionStateChanged;

  @override
  State<ScrollWorldView> createState() => _ScrollWorldViewState();
}

final class _ScrollWorldViewState extends State<ScrollWorldView>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late ScrollWorldTimeline _timeline;
  late ScrollController _scrollController;
  late VideoControllerPool _pool;
  late ScrollWorldController _journeyController;
  late final Ticker _smoothingTicker;
  final FocusNode _focusNode = FocusNode(debugLabel: 'ScrollWorld');
  double _viewportHeight = 0;
  ScrollWorldEnvironment? _environment;
  bool _reducedMotion = false;
  bool _reportedLoading = false;
  int _activeSceneIndex = -1;
  bool _releaseScheduled = false;
  double _displayedLogicalOffset = 0;
  double _targetLogicalOffset = 0;
  ScrollWorldMotionState _motionState = ScrollWorldMotionState.idle;
  bool _programmaticMotion = false;
  int _motionGeneration = 0;
  Timer? _scrollIdleTimer;
  bool _primed = false;
  bool _replayButtonLocked = false;
  late Duration _poolSeekTolerance;

  bool get _ownsScrollController => widget.scrollController == null;

  ScrollWorldFrame? get _currentFrame {
    if (_timeline.segments.isEmpty || _viewportHeight <= 0) return null;
    return _timeline.sampleAt(
      _displayedLogicalOffset,
      transitionCurve: widget.configuration.transitionCurve,
      seamFadeFraction: widget.configuration.seamFadeFraction,
      useConnectors: !_reducedMotion,
    );
  }

  @override
  void initState() {
    super.initState();
    widget.configuration.validate();
    _timeline = ScrollWorldTimeline.compile(widget.scenes);
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_handleScroll);
    _journeyController = widget.controller ?? ScrollWorldController();
    _attachJourneyController();
    _smoothingTicker = createTicker(_handleSmoothingTick);
    _createPool();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(ScrollWorldView oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.configuration.validate();
    if (!listEquals(oldWidget.scenes, widget.scenes)) {
      _timeline = ScrollWorldTimeline.compile(widget.scenes);
      _activeSceneIndex = -1;
    }
    if (oldWidget.scrollController != widget.scrollController) {
      _scrollController.removeListener(_handleScroll);
      if (oldWidget.scrollController == null) _scrollController.dispose();
      _scrollController = widget.scrollController ?? ScrollController();
      _scrollController.addListener(_handleScroll);
    }
    if (oldWidget.controller != widget.controller) {
      final previousController = _journeyController;
      _journeyController.detach();
      if (oldWidget.controller == null) previousController.dispose();
      _journeyController = widget.controller ?? ScrollWorldController();
      _attachJourneyController();
    }
    if (oldWidget.driverFactory != widget.driverFactory ||
        oldWidget.configuration.seekTolerance !=
            widget.configuration.seekTolerance ||
        oldWidget.configuration.maximumSeekFrequency !=
            widget.configuration.maximumSeekFrequency ||
        oldWidget.configuration.mobileSeekTolerance !=
            widget.configuration.mobileSeekTolerance ||
        oldWidget.configuration.initializationRetryCount !=
            widget.configuration.initializationRetryCount ||
        oldWidget.configuration.webMediaStrategy !=
            widget.configuration.webMediaStrategy) {
      _pool.removeListener(_handlePoolChanged);
      _pool.dispose();
      _createPool();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPlayback());
  }

  void _createPool() {
    final mobile =
        !kIsWeb ||
        ((_environment?.viewportWidth ?? double.infinity) <
            widget.configuration.mobileBreakpoint);
    _poolSeekTolerance = mobile
        ? widget.configuration.mobileSeekTolerance
        : widget.configuration.seekTolerance;
    _pool = VideoControllerPool(
      factory:
          widget.driverFactory ??
          VideoPlayerDriverFactory(
            webMediaStrategy: widget.configuration.webMediaStrategy,
          ),
      seekTolerance: _poolSeekTolerance,
      maximumSeekFrequency: widget.configuration.maximumSeekFrequency,
      initializationRetryCount: widget.configuration.initializationRetryCount,
      onError: widget.onError,
    )..addListener(_handlePoolChanged);
  }

  void _attachJourneyController() {
    _journeyController.attach(
      animateToScene: _animateToSceneById,
      jumpToScene: _jumpToSceneById,
      replayReverse: _replayReverse,
      cancelMotion: _cancelProgrammaticMotion,
    );
    _updateJourneyController();
  }

  void _setMotionState(ScrollWorldMotionState state) {
    if (_motionState == state) return;
    _motionState = state;
    widget.onMotionStateChanged?.call(state);
    _updateJourneyController();
    if (mounted) setState(() {});
  }

  void _updateJourneyController() {
    final frame = _currentFrame;
    _journeyController.update(
      overallProgress: frame?.overallProgress ?? 0,
      activeSceneId: frame == null
          ? null
          : widget.scenes[frame.activeSceneIndex].id,
      motionState: _motionState,
    );
  }

  Future<void> _animateToSceneById(
    String sceneId,
    Duration? duration,
    Curve? curve,
  ) async {
    final index = widget.scenes.indexWhere((scene) => scene.id == sceneId);
    if (index < 0) throw ArgumentError.value(sceneId, 'sceneId', 'not found');
    await _animateToLogicalOffset(
      _timeline.sceneMidpoint(index),
      duration: duration ?? widget.configuration.navigationDuration,
      curve: curve ?? Curves.easeInOutCubic,
      state: ScrollWorldMotionState.navigating,
    );
  }

  void _jumpToSceneById(String sceneId) {
    final index = widget.scenes.indexWhere((scene) => scene.id == sceneId);
    if (index < 0) throw ArgumentError.value(sceneId, 'sceneId', 'not found');
    _cancelProgrammaticMotion();
    _jumpToLogicalOffset(_timeline.sceneMidpoint(index));
  }

  Future<void> _replayReverse(Duration? duration, Curve? curve) async {
    if (_motionState == ScrollWorldMotionState.replayingReverse) return;
    final fullDuration = duration ?? widget.configuration.reverseReplayDuration;
    final progress = _timeline.totalExtent == 0
        ? 0.0
        : (_displayedLogicalOffset / _timeline.totalExtent).clamp(0.0, 1.0);
    final scaled = Duration(
      microseconds: (fullDuration.inMicroseconds * progress).round(),
    );
    await _animateToLogicalOffset(
      0,
      duration: scaled,
      curve: curve ?? Curves.easeInOutSine,
      state: ScrollWorldMotionState.replayingReverse,
    );
  }

  Future<void> _animateToLogicalOffset(
    double logicalOffset, {
    required Duration duration,
    required Curve curve,
    required ScrollWorldMotionState state,
  }) async {
    if (!_scrollController.hasClients || _viewportHeight <= 0) return;
    _cancelProgrammaticMotion();
    final generation = ++_motionGeneration;
    _programmaticMotion = true;
    _setMotionState(state);
    final target = (logicalOffset * _viewportHeight).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    if (_reducedMotion || duration <= Duration.zero) {
      _scrollController.jumpTo(target);
      _displayedLogicalOffset = logicalOffset;
      _targetLogicalOffset = logicalOffset;
    } else {
      try {
        await _scrollController.animateTo(
          target,
          duration: duration,
          curve: curve,
        );
      } on Object {
        // User input cancels ScrollPosition activities; the generation decides
        // whether this completion still owns the motion state.
      }
    }
    if (!mounted || generation != _motionGeneration) return;
    _targetLogicalOffset = logicalOffset;
    _displayedLogicalOffset = logicalOffset;
    _smoothingTicker.stop();
    _programmaticMotion = false;
    setState(() {});
    _syncPlayback();
    _setMotionState(ScrollWorldMotionState.idle);
  }

  void _jumpToLogicalOffset(double logicalOffset) {
    if (!_scrollController.hasClients || _viewportHeight <= 0) return;
    final target = (logicalOffset * _viewportHeight).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.jumpTo(target);
    _targetLogicalOffset = logicalOffset;
    _displayedLogicalOffset = logicalOffset;
    setState(() {});
    _syncPlayback();
  }

  void _cancelProgrammaticMotion() {
    if (!_programmaticMotion) return;
    _motionGeneration++;
    _programmaticMotion = false;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.offset);
    }
    _setMotionState(ScrollWorldMotionState.idle);
  }

  void _handleUserInput() {
    _cancelProgrammaticMotion();
    if (_primed) return;
    _primed = true;
    unawaited(_pool.primeAll());
  }

  void _handleScroll() {
    if (!mounted) return;
    if (_viewportHeight <= 0 || !_scrollController.hasClients) return;
    _targetLogicalOffset = (_scrollController.offset / _viewportHeight).clamp(
      0.0,
      _timeline.totalExtent,
    );
    if (_reducedMotion || widget.configuration.smoothingFactor == 1) {
      _displayedLogicalOffset = _targetLogicalOffset;
      setState(() {});
      _syncPlayback();
      return;
    }
    if (!_programmaticMotion) {
      _setMotionState(ScrollWorldMotionState.userScrolling);
      _scrollIdleTimer?.cancel();
      _scrollIdleTimer = Timer(const Duration(milliseconds: 120), () {
        if (!_programmaticMotion && !_smoothingTicker.isActive) {
          _setMotionState(ScrollWorldMotionState.idle);
        }
      });
    }
    if (!_smoothingTicker.isActive) _smoothingTicker.start();
  }

  void _handleSmoothingTick(Duration elapsed) {
    if (!mounted) return;
    final delta = _targetLogicalOffset - _displayedLogicalOffset;
    if (delta.abs() <= 0.0005) {
      _displayedLogicalOffset = _targetLogicalOffset;
      _smoothingTicker.stop();
      if (!_programmaticMotion) _setMotionState(ScrollWorldMotionState.idle);
    } else {
      _displayedLogicalOffset = interpolateScrollProgress(
        displayed: _displayedLogicalOffset,
        target: _targetLogicalOffset,
        factor: widget.configuration.smoothingFactor,
      );
    }
    setState(() {});
    _syncPlayback();
  }

  void _handlePoolChanged() {
    if (!mounted) return;
    setState(() {});
    widget.onDebugSnapshot?.call(_pool.debugSnapshot);
    _reportLoading();
    _seekNearbyMedia();
  }

  void _reportLoading() {
    final frame = _currentFrame;
    final loading =
        frame?.layers.any(
          (layer) => _pool.entryFor(layer.mediaKey)?.isLoading ?? false,
        ) ??
        false;
    if (loading == _reportedLoading) return;
    _reportedLoading = loading;
    widget.onLoadingChanged?.call(loading);
  }

  void _syncPlayback({int? radiusOverride}) {
    if (!mounted || _timeline.segments.isEmpty || _environment == null) return;
    final frame = _currentFrame;
    if (frame == null) return;
    _reportScene(frame.activeSceneIndex);

    if (_reducedMotion) {
      if (!_releaseScheduled) {
        _releaseScheduled = true;
        unawaited(
          _pool.releaseAll().whenComplete(() => _releaseScheduled = false),
        );
      }
      return;
    }

    final radius = radiusOverride ?? widget.configuration.preloadRadius;
    final desired = <ScrollWorldMediaKey, ScrollWorldSource>{};
    final first = (frame.segment.index - radius).clamp(
      0,
      _timeline.segments.length - 1,
    );
    final last = (frame.segment.index + radius).clamp(
      0,
      _timeline.segments.length - 1,
    );
    for (var index = first; index <= last; index++) {
      final segment = _timeline.segments[index];
      final key = segment.ownMediaKey;
      if (key != null) desired[key] = _sourceFor(key);
    }
    for (final layer in frame.layers) {
      desired[layer.mediaKey] = _sourceFor(layer.mediaKey);
    }
    _pool.reconcile(desired);
    _seekMediaKeys(desired.keys);
    _reportLoading();
    _updateJourneyController();
  }

  void _seekNearbyMedia() {
    if (_reducedMotion) return;
    final frame = _currentFrame;
    if (frame == null) return;
    final radius = widget.configuration.preloadRadius;
    final first = (frame.segment.index - radius).clamp(
      0,
      _timeline.segments.length - 1,
    );
    final last = (frame.segment.index + radius).clamp(
      0,
      _timeline.segments.length - 1,
    );
    final keys = <ScrollWorldMediaKey>{
      for (var index = first; index <= last; index++)
        ?_timeline.segments[index].ownMediaKey,
      ...frame.layers.map((layer) => layer.mediaKey),
    };
    _seekMediaKeys(keys);
  }

  void _seekMediaKeys(Iterable<ScrollWorldMediaKey> keys) {
    for (final key in keys) {
      final segment = _timeline.segments.firstWhere(
        (candidate) => candidate.ownMediaKey == key,
        orElse: () => _timeline.sceneSegment(key.index),
      );
      unawaited(
        _pool.seek(key, segment.mediaProgressAt(_displayedLogicalOffset)),
      );
    }
  }

  ScrollWorldSource _sourceFor(ScrollWorldMediaKey key) {
    final sources = switch (key.kind) {
      ScrollWorldMediaKind.scene => widget.scenes[key.index].sources,
      ScrollWorldMediaKind.connector =>
        widget.scenes[key.index].connectorToNext!,
    };
    return selectScrollWorldSource(
      sources,
      _environment!,
      mobileBreakpoint: widget.configuration.mobileBreakpoint,
      webHighPhysicalWidth: widget.configuration.webHighPhysicalWidth,
    );
  }

  ImageProvider<Object> _posterFor(ScrollWorldMediaKey key) {
    final scene = switch (key.kind) {
      ScrollWorldMediaKind.scene => widget.scenes[key.index],
      ScrollWorldMediaKind.connector => widget.scenes[key.index + 1],
    };
    if (_reducedMotion && scene.reducedMotionImage != null) {
      return scene.reducedMotionImage!;
    }
    return scene.poster;
  }

  void _reportScene(int index) {
    if (_activeSceneIndex == index ||
        index < 0 ||
        index >= widget.scenes.length) {
      return;
    }
    _activeSceneIndex = index;
    widget.onSceneChanged?.call(widget.scenes[index], index);
  }

  void _updateEnvironment(
    Size size,
    double devicePixelRatio,
    bool reducedMotion,
  ) {
    if (size.height <= 0 || size.width <= 0) return;
    final oldHeight = _viewportHeight;
    final logicalOffset = oldHeight > 0 && _scrollController.hasClients
        ? _scrollController.offset / oldHeight
        : 0.0;
    final next = ScrollWorldEnvironment(
      isWeb: kIsWeb,
      isPortrait: size.height >= size.width,
      viewportWidth: size.width,
      devicePixelRatio: devicePixelRatio,
    );
    final changed =
        _environment?.isPortrait != next.isPortrait ||
        _environment?.viewportWidth != next.viewportWidth ||
        _environment?.devicePixelRatio != next.devicePixelRatio ||
        _environment?.isWeb != next.isWeb ||
        _reducedMotion != reducedMotion ||
        oldHeight != size.height;
    _environment = next;
    _viewportHeight = size.height;
    _reducedMotion = reducedMotion;
    if (oldHeight > 0 && oldHeight != size.height) {
      _targetLogicalOffset = logicalOffset;
      _displayedLogicalOffset = logicalOffset;
    }
    if (reducedMotion) {
      _targetLogicalOffset = logicalOffset;
      _displayedLogicalOffset = logicalOffset;
      _smoothingTicker.stop();
    }
    if (!changed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final desiredTolerance =
          (!kIsWeb ||
              next.viewportWidth < widget.configuration.mobileBreakpoint)
          ? widget.configuration.mobileSeekTolerance
          : widget.configuration.seekTolerance;
      if (desiredTolerance != _poolSeekTolerance) {
        _pool.removeListener(_handlePoolChanged);
        _pool.dispose();
        _createPool();
      }
      if (_scrollController.hasClients &&
          oldHeight > 0 &&
          oldHeight != size.height) {
        final max = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo((logicalOffset * size.height).clamp(0.0, max));
      }
      _syncPlayback();
    });
  }

  double _sceneProgress(ScrollWorldFrame frame) {
    if (frame.segment.kind == ScrollWorldSegmentKind.scene) {
      return frame.segmentProgress;
    }
    return frame.activeSceneIndex == frame.segment.sceneIndex ? 1 : 0;
  }

  Future<void> _jumpToScene(int index) async {
    _handleUserInput();
    if (_reducedMotion) {
      _jumpToLogicalOffset(_timeline.sceneMidpoint(index));
      return;
    }
    await _animateToSceneById(widget.scenes[index].id, null, null);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !_scrollController.hasClients) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final position = _scrollController.position;
    double? target;
    if (key == LogicalKeyboardKey.arrowDown) {
      target = position.pixels + 80;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      target = position.pixels - 80;
    } else if (key == LogicalKeyboardKey.pageDown) {
      target = position.pixels + _viewportHeight * 0.8;
    } else if (key == LogicalKeyboardKey.pageUp) {
      target = position.pixels - _viewportHeight * 0.8;
    } else if (key == LogicalKeyboardKey.home) {
      target = 0;
    } else if (key == LogicalKeyboardKey.end) {
      target = position.maxScrollExtent;
    }
    if (target == null) return KeyEventResult.ignored;
    _handleUserInput();
    _scrollController.jumpTo(target.clamp(0.0, position.maxScrollExtent));
    _targetLogicalOffset =
        _scrollController.offset / math.max(_viewportHeight, 1);
    _displayedLogicalOffset = _targetLogicalOffset;
    _smoothingTicker.stop();
    setState(() {});
    _syncPlayback();
    return KeyEventResult.handled;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _syncPlayback();
        break;
      case AppLifecycleState.inactive:
        unawaited(_pool.pauseAll());
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_pool.releaseAll());
        break;
    }
  }

  @override
  void didHaveMemoryPressure() {
    _syncPlayback(radiusOverride: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.scenes.isEmpty) {
      return widget.emptyBuilder?.call(context) ?? const SizedBox.shrink();
    }
    final media = MediaQuery.of(context);
    final reduced =
        widget.configuration.respectReducedMotion && media.disableAnimations;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _updateEnvironment(size, media.devicePixelRatio, reduced);
        final frame =
            _currentFrame ??
            _timeline.sampleAt(
              0,
              transitionCurve: widget.configuration.transitionCurve,
              seamFadeFraction: widget.configuration.seamFadeFraction,
              useConnectors: !reduced,
            );
        return Listener(
          onPointerDown: (_) => _handleUserInput(),
          onPointerSignal: (_) => _handleUserInput(),
          child: ColoredBox(
            color: widget.theme.backgroundColor,
            child: Focus(
              focusNode: _focusNode,
              autofocus: true,
              onKeyEvent: _handleKey,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ...frame.layers.map(_buildLayer),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: widget.theme.overlayGradient,
                    ),
                  ),
                  _buildScrollTrack(size.height),
                  _buildOverlay(context, frame),
                  if (_reportedLoading)
                    const IgnorePointer(
                      child: Center(
                        child: CircularProgressIndicator.adaptive(
                          backgroundColor: Color(0x55FFFFFF),
                        ),
                      ),
                    ),
                  _buildOverallProgress(frame.overallProgress),
                  if (widget.configuration.showProgressNavigation)
                    _buildNavigation(frame.activeSceneIndex),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLayer(ScrollWorldLayerFrame layer) {
    final entry = _pool.entryFor(layer.mediaKey);
    return Positioned.fill(
      key: ValueKey<String>(layer.mediaKey.value),
      child: IgnorePointer(
        child: Opacity(
          opacity: layer.opacity.clamp(0.0, 1.0),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image(
                image: _posterFor(layer.mediaKey),
                fit: widget.configuration.fit,
                errorBuilder: (context, error, stackTrace) =>
                    ColoredBox(color: widget.theme.backgroundColor),
              ),
              if (!_reducedMotion &&
                  entry != null &&
                  entry.ready &&
                  entry.hasFrame)
                entry.driver.buildView(fit: widget.configuration.fit),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context, ScrollWorldFrame frame) {
    final sceneIndex = frame.activeSceneIndex;
    final scene = widget.scenes[sceneIndex];
    final progress = _sceneProgress(frame);
    final visibility = ScrollWorldTimeline.overlayVisibility(
      sceneIndex: sceneIndex,
      sceneCount: widget.scenes.length,
      sceneProgress: progress,
    );
    final narrative =
        widget.overlayBuilder?.call(context, scene, progress, visibility) ??
        _DefaultSceneOverlay(scene: scene, theme: widget.theme);
    final actions = scene.actions
        .map((action) => _buildAction(context, scene, action))
        .toList(growable: false);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        narrative,
        if (actions.isNotEmpty) ...<Widget>[
          SizedBox(height: widget.theme.actionSpacing),
          Wrap(spacing: 12, runSpacing: 12, children: actions),
        ],
      ],
    );
    final translate =
        !_reducedMotion &&
            scene.overlayAnimation == ScrollWorldOverlayAnimation.fadeSlide
        ? (0.5 - progress) * 32
        : 0.0;
    final opacity = scene.overlayAnimation == ScrollWorldOverlayAnimation.none
        ? 1.0
        : visibility;
    return SafeArea(
      child: Padding(
        padding: widget.theme.overlayPadding,
        child: Align(
          alignment: scene.overlayAlignment,
          child: IgnorePointer(
            ignoring: opacity < 0.5,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, translate),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: widget.theme.overlayMaxWidth,
                  ),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAction(
    BuildContext context,
    ScrollWorldScene scene,
    ScrollWorldAction action,
  ) {
    final available =
        !_replayButtonLocked &&
        _motionState != ScrollWorldMotionState.replayingReverse &&
        (action.intent != ScrollWorldActionIntent.custom ||
            widget.onAction != null);
    final onPressed = available
        ? () => unawaited(_activateAction(scene, action))
        : null;
    if (widget.actionBuilder case final builder?) {
      return builder(context, scene, action, onPressed);
    }
    final icon = switch (action.intent) {
      ScrollWorldActionIntent.replayReverse => Icons.replay_rounded,
      ScrollWorldActionIntent.navigateToScene => Icons.arrow_forward_rounded,
      ScrollWorldActionIntent.custom => Icons.touch_app_rounded,
    };
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 19),
        const SizedBox(width: 9),
        Text(action.label),
      ],
    );
    return Semantics(
      excludeSemantics: true,
      button: true,
      enabled: available,
      label: action.semanticLabel ?? action.label,
      child: action.style == ScrollWorldActionStyle.primary
          ? FilledButton(onPressed: onPressed, child: child)
          : OutlinedButton(onPressed: onPressed, child: child),
    );
  }

  Future<void> _activateAction(
    ScrollWorldScene scene,
    ScrollWorldAction action,
  ) async {
    switch (action.intent) {
      case ScrollWorldActionIntent.replayReverse:
        if (_replayButtonLocked) return;
        setState(() => _replayButtonLocked = true);
        final callback = widget.onAction;
        if (callback != null) {
          unawaited(Future.sync(() => callback(scene, action)));
        }
        try {
          await _journeyController.replayReverse();
        } finally {
          if (mounted) setState(() => _replayButtonLocked = false);
        }
        break;
      case ScrollWorldActionIntent.navigateToScene:
        final callback = widget.onAction;
        if (callback != null) {
          unawaited(Future.sync(() => callback(scene, action)));
        }
        await _journeyController.animateToScene(action.targetSceneId!);
        break;
      case ScrollWorldActionIntent.custom:
        await widget.onAction?.call(scene, action);
        break;
    }
  }

  Widget _buildScrollTrack(double height) => Positioned.fill(
    child: SingleChildScrollView(
      controller: _scrollController,
      physics: const ClampingScrollPhysics(),
      child: SizedBox(height: (_timeline.totalExtent + 1) * height),
    ),
  );

  Widget _buildOverallProgress(double progress) => SafeArea(
    child: Align(
      alignment: Alignment.topCenter,
      child: LinearProgressIndicator(
        minHeight: 3,
        value: progress,
        backgroundColor: widget.theme.progressInactiveColor,
        valueColor: AlwaysStoppedAnimation<Color>(
          widget.theme.progressActiveColor,
        ),
      ),
    ),
  );

  Widget _buildNavigation(int activeIndex) => SafeArea(
    minimum: const EdgeInsets.only(right: 12),
    child: Align(
      alignment: Alignment.centerRight,
      child: Semantics(
        container: true,
        label: 'Scene navigation',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(widget.scenes.length, (index) {
            final scene = widget.scenes[index];
            final active = index == activeIndex;
            return Semantics(
              button: true,
              selected: active,
              label:
                  'Scene ${index + 1} of ${widget.scenes.length}: ${scene.title ?? scene.id}',
              child: IconButton(
                tooltip: scene.title ?? scene.id,
                onPressed: () => unawaited(_jumpToScene(index)),
                icon: AnimatedContainer(
                  duration: _reducedMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  width: active ? 14 : 10,
                  height: active ? 14 : 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? widget.theme.progressActiveColor
                        : widget.theme.progressInactiveColor,
                    border: Border.all(
                      color: Colors.white,
                      width: active ? 2 : 1,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollIdleTimer?.cancel();
    _smoothingTicker.dispose();
    _journeyController.detach();
    if (widget.controller == null) _journeyController.dispose();
    _pool
      ..removeListener(_handlePoolChanged)
      ..dispose();
    _scrollController.removeListener(_handleScroll);
    if (_ownsScrollController) _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

final class _DefaultSceneOverlay extends StatelessWidget {
  const _DefaultSceneOverlay({required this.scene, required this.theme});

  final ScrollWorldScene scene;
  final ScrollWorldTheme theme;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    header: true,
    label: <String?>[
      scene.title,
      scene.description,
    ].whereType<String>().join('. '),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (scene.title case final title?)
          Text(
            title,
            style:
                theme.titleStyle ??
                Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                ),
          ),
        if (scene.description case final description?) ...<Widget>[
          const SizedBox(height: 14),
          Text(
            description,
            style:
                theme.descriptionStyle ??
                Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFE8ECEA),
                  height: 1.45,
                ),
          ),
        ],
      ],
    ),
  );
}
