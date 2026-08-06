import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';

import '../app.dart';
import '../theme/padlo_theme.dart';
import '../widgets/padlo_primitives.dart';
import '../world/padlo_scene_runtime.dart';
import '../world/padlo_world_timeline.dart';

final class PadloWorldScreen extends StatefulWidget {
  const PadloWorldScreen({
    required this.routeLocation,
    this.routeChild,
    super.key,
  });

  final String routeLocation;
  final Widget? routeChild;

  @override
  State<PadloWorldScreen> createState() => _PadloWorldScreenState();
}

final class _PadloWorldScreenState extends State<PadloWorldScreen>
    with WidgetsBindingObserver {
  final _timeline = const PadloWorldTimeline();
  final _worldController = PadloWorldController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode(debugLabel: 'Padlo world scroll');
  late final PadloSceneRuntime _runtime;

  bool _loading = true;
  bool _sceneError = false;
  bool _paused = false;
  bool _reducedMotion = false;
  bool _restoredCheckpoint = false;
  bool _syncingScroll = false;
  String? _feedback;
  double _viewportHeight = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runtime = PadloSceneRuntime(onChoice: _onChoice);
    if (!_runtime.canRender) {
      _loading = false;
      _sceneError = true;
    }
    _scrollController.addListener(_onScroll);
    _worldController.addListener(_onWorldChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadScene());
    });
  }

  Future<void> _loadScene({bool recover = false}) async {
    if (!_runtime.canRender) {
      if (mounted) {
        setState(() {
          _loading = false;
          _sceneError = true;
        });
      }
      return;
    }
    try {
      if (recover) {
        await _runtime.recover();
      } else {
        await _runtime.load();
      }
      if (!mounted) return;
      _runtime.addChoicePanels();
      final challenges = PadloScope.of(context).completedChallenges;
      if (challenges.contains('pressure-zone')) {
        _worldController.releaseGate('positioning-lab');
      }
      if (challenges.contains('recover-first')) {
        _worldController.releaseGate('decision-gate');
      }
      _restoreCheckpoint();
      setState(() => _loading = false);
    } on Object catch (error, stackTrace) {
      debugPrint('Padlo real-time scene failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _loading = false;
          _sceneError = true;
        });
      }
    }
  }

  Future<void> _recoverScene() => _loadScene(recover: true);

  void _restoreCheckpoint() {
    if (_restoredCheckpoint ||
        !_scrollController.hasClients ||
        _viewportHeight <= 0) {
      return;
    }
    _restoredCheckpoint = true;
    final checkpoint = PadloScope.of(context).worldCheckpoint;
    final progress = switch (checkpoint) {
      'positioning-lab' => 0.36,
      'decision-gate' => 0.74,
      _ => 0.0,
    };
    _worldController.jumpToProgress(progress);
    _scrollController.jumpTo(
      _timeline.offsetForProgress(progress, _viewportHeight),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = MediaQuery.disableAnimationsOf(context);
    if (next == _reducedMotion) return;
    _reducedMotion = next;
    _runtime.setReducedMotion(next);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
  }

  void _onScroll() {
    if (_syncingScroll || _viewportHeight <= 0) return;
    final raw = _timeline.progressForOffset(
      _scrollController.offset,
      _viewportHeight,
    );
    _worldController.setRawProgress(raw);
  }

  void _onWorldChanged() {
    if (!mounted) return;
    final scene = _worldController.activeChapter;
    final store = PadloScope.of(context);
    if (store.worldCheckpoint != scene.id) {
      unawaited(store.setWorldCheckpoint(scene.id));
    }
    if (_worldController.motionState == PadloWorldMotionState.replaying &&
        _scrollController.hasClients) {
      _syncingScroll = true;
      _scrollController.jumpTo(
        _timeline.offsetForProgress(
          _worldController.renderedProgress,
          _viewportHeight,
        ),
      );
      _syncingScroll = false;
    }
  }

  void _onChoice(String choice) {
    final chapter = _worldController.activeChapter.id;
    setState(() {
      _feedback = switch (choice) {
        'Pressure zone' =>
          'Correct. Keep the pair inside the blue pressure band.',
        'Recover' => 'Correct. Recover before the next ball closes the middle.',
        'Attack' => 'Good read. Attack only when the pair arrives together.',
        'Hold' => 'Solid hold. Keep the net and wait for the next cue.',
        _ => 'That band gives the opponents the advantage. Try again.',
      };
    });
    if ((chapter == 'positioning-lab' && choice == 'Pressure zone') ||
        (chapter == 'decision-gate' && choice == 'Recover')) {
      final challenge = chapter == 'positioning-lab'
          ? 'pressure-zone'
          : 'recover-first';
      unawaited(PadloScope.of(context).completeChallenge(challenge));
      _worldController.releaseGate(chapter);
      _nudgePastGate(chapter);
    }
  }

  void _nudgePastGate(String chapterId) {
    final chapter = _timeline.chapters.firstWhere(
      (item) => item.id == chapterId,
    );
    final next = (chapter.gateAt ?? chapter.start) + 0.008;
    _worldController.setRawProgress(next, userInitiated: false);
    if (_scrollController.hasClients && _viewportHeight > 0) {
      _scrollController.animateTo(
        _timeline.offsetForProgress(next, _viewportHeight),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    final amount = _viewportHeight * 0.38;
    if (key == LogicalKeyboardKey.home) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else if (key == LogicalKeyboardKey.end) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.pageDown) {
      _scrollController.animateTo(
        (_scrollController.offset + amount)
            .clamp(0.0, _scrollController.position.maxScrollExtent)
            .toDouble(),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.pageUp) {
      _scrollController.animateTo(
        (_scrollController.offset - amount)
            .clamp(0.0, _scrollController.position.maxScrollExtent)
            .toDouble(),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _replay() {
    if (_worldController.isReplaying) return;
    if (_reducedMotion) {
      _worldController.jumpToProgress(0);
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      return;
    }
    _worldController.startReplay();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportHeight = constraints.maxHeight;
        _runtime.resize(Size(constraints.maxWidth, constraints.maxHeight));
        if (_runtime.isLoaded) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _restoreCheckpoint(),
          );
        }
        return Scaffold(
          backgroundColor: PadloTokens.darkSurface,
          body: Focus(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: (node, event) {
              _handleKey(event);
              return KeyEventResult.handled;
            },
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (!_sceneError) Positioned.fill(child: _buildScene()),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.black.withValues(alpha: 0.08),
                            Colors.transparent,
                            PadloTokens.darkSurface.withValues(alpha: 0.94),
                          ],
                          stops: const <double>[0, 0.55, 1],
                        ),
                      ),
                    ),
                  ),
                ),
                _buildScrollSpace(),
                _WorldHud(
                  controller: _worldController,
                  sceneError: _sceneError,
                  feedback: _feedback,
                  onReplay: _replay,
                  onChoice: _onChoice,
                  onRetry: () {
                    setState(() {
                      _sceneError = false;
                      _loading = true;
                    });
                    unawaited(_recoverScene());
                  },
                ),
                if (_loading) const _SceneLoading(),
                if (_sceneError) const _SceneFallback(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScene() => SceneView(
    _runtime.scene,
    cameraBuilder: (_) => _runtime.cameraFor(_worldController.renderedProgress),
    onTick: (_, deltaSeconds) {
      if (_paused || !_runtime.isLoaded) return;
      _worldController.tick(deltaSeconds, reducedMotion: _reducedMotion);
      _runtime.seek(_worldController.renderedProgress);
    },
    loadingBuilder: (context, progress) => _SceneLoading(progress: progress),
    warmUp: true,
  );

  Widget _buildScrollSpace() => Positioned.fill(
    child: NotificationListener<ScrollNotification>(
      onNotification: (_) => false,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
        child: SizedBox(height: _viewportHeight * _timeline.extentFactor),
      ),
    ),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _worldController.removeListener(_onWorldChanged);
    _scrollController.removeListener(_onScroll);
    _runtime.dispose();
    _worldController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

final class _WorldHud extends StatelessWidget {
  const _WorldHud({
    required this.controller,
    required this.sceneError,
    required this.feedback,
    required this.onReplay,
    required this.onChoice,
    required this.onRetry,
  });

  final PadloWorldController controller;
  final bool sceneError;
  final String? feedback;
  final VoidCallback onReplay;
  final ValueChanged<String> onChoice;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SafeArea(
    minimum: const EdgeInsets.fromLTRB(24, 20, 24, 24),
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final chapter = controller.activeChapter;
        final local = chapter.localProgress(controller.renderedProgress);
        final gateBlocked = controller.isGateBlocked;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Align(
              alignment: Alignment.topLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const PadloLogo(light: true, height: 30),
                  const SizedBox(width: 16),
                  _ChapterPill(chapter: chapter, localProgress: local),
                ],
              ),
            ),
            Align(alignment: Alignment.topRight, child: ProofOfConceptBadge()),
            Align(
              alignment: Alignment.bottomLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: _ChapterCopy(
                  chapter: chapter,
                  feedback: feedback,
                  gateBlocked: gateBlocked,
                  onChoice: onChoice,
                ),
              ),
            ),
            if (chapter.id == 'decision-gate' &&
                controller.renderedProgress > 0.80)
              Align(
                alignment: Alignment.bottomRight,
                child: FilledButton.icon(
                  key: const Key('replay-journey'),
                  onPressed: controller.isReplaying ? null : onReplay,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Replay the journey'),
                ),
              ),
            if (sceneError)
              Align(
                alignment: Alignment.center,
                child: FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry the 3D world'),
                ),
              ),
          ],
        );
      },
    ),
  );
}

final class _ChapterPill extends StatelessWidget {
  const _ChapterPill({required this.chapter, required this.localProgress});

  final PadloWorldChapter chapter;
  final double localProgress;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: PadloTokens.darkSurface.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            chapter.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 64,
            child: LinearProgressIndicator(
              value: localProgress,
              minHeight: 4,
              backgroundColor: Colors.white24,
              color: PadloTokens.accent,
            ),
          ),
        ],
      ),
    ),
  );
}

final class _ChapterCopy extends StatelessWidget {
  const _ChapterCopy({
    required this.chapter,
    required this.feedback,
    required this.gateBlocked,
    required this.onChoice,
  });

  final PadloWorldChapter chapter;
  final String? feedback;
  final bool gateBlocked;
  final ValueChanged<String> onChoice;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(
        chapter.title,
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          height: 0.98,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        chapter.description,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 16,
          height: 1.35,
        ),
      ),
      if (gateBlocked) ...<Widget>[
        const SizedBox(height: 14),
        const Text(
          'Choose the highlighted path to keep moving.',
          style: TextStyle(
            color: PadloTokens.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
      if (feedback != null) ...<Widget>[
        const SizedBox(height: 14),
        DecoratedBox(
          decoration: BoxDecoration(
            color: PadloTokens.darkSurface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              feedback!,
              style: const TextStyle(color: Colors.white, height: 1.3),
            ),
          ),
        ),
      ],
      if (chapter.id == 'positioning-lab' ||
          chapter.id == 'decision-gate') ...<Widget>[
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              (chapter.id == 'positioning-lab'
                      ? const <String>['Pressure zone', 'Error band']
                      : const <String>['Attack', 'Hold', 'Recover'])
                  .map(
                    (choice) => OutlinedButton(
                      onPressed: () => onChoice(choice),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: PadloTokens.accent.withValues(alpha: 0.8),
                        ),
                      ),
                      child: Text(choice),
                    ),
                  )
                  .toList(),
        ),
      ],
      const SizedBox(height: 12),
      const Text(
        'Scroll to steer the camera',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      ),
    ],
  );
}

final class _SceneLoading extends StatelessWidget {
  const _SceneLoading({this.progress});

  final double? progress;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: PadloTokens.darkSurface,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(color: PadloTokens.accent),
          const SizedBox(height: 14),
          Text(
            progress == null
                ? 'Loading the Padlo court…'
                : 'Loading ${(progress! * 100).round()}%',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    ),
  );
}

final class _SceneFallback extends StatelessWidget {
  const _SceneFallback();

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      liveRegion: true,
      label:
          'The real-time 3D scene could not be loaded. The coaching journey is unavailable.',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PadloTokens.darkSurface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PadloTokens.accent.withValues(alpha: 0.45)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(22),
          child: Text(
            'Padlo 3D world unavailable\nCheck WebGL2 support and retry.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, height: 1.4),
          ),
        ),
      ),
    ),
  );
}
