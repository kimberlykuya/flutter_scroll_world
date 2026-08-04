import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:scroll_world/scroll_world.dart';

import '../app.dart';
import '../theme/padlo_theme.dart';
import '../widgets/padlo_primitives.dart';

final _onboardingScenes = <ScrollWorldScene>[
  ScrollWorldScene(
    id: 'see-court',
    title: 'See the court differently',
    description:
        'Positioning changes the point before the racket does. Scroll into a Ljubljana evening match and see the spaces that decide it.',
    poster: const AssetImage('assets/posters/see-court.webp'),
    reducedMotionImage: const AssetImage('assets/posters/see-court.webp'),
    sources: _sceneSources('see-court'),
    connectorToNext: _connectorSources('see-court-net-depth'),
    scrollExtent: 2.2,
    transitionExtent: 0.8,
    linger: 0.4,
  ),
  ScrollWorldScene(
    id: 'net-depth',
    title: 'Own the right net depth',
    description:
        'Too deep and the pressure disappears. Padlo marks the distance that keeps your pair in control.',
    poster: const AssetImage('assets/posters/net-depth.webp'),
    reducedMotionImage: const AssetImage('assets/posters/net-depth.webp'),
    sources: _sceneSources('net-depth'),
    connectorToNext: _connectorSources('net-depth-recovery'),
    scrollExtent: 2.2,
    transitionExtent: 0.8,
    linger: 0.4,
  ),
  ScrollWorldScene(
    id: 'recovery',
    title: 'Recover before the next ball',
    description:
        'After every bandeja, your first step matters. Compare the late path with the movement that protects the middle.',
    poster: const AssetImage('assets/posters/recovery.webp'),
    reducedMotionImage: const AssetImage('assets/posters/recovery.webp'),
    sources: _sceneSources('recovery'),
    connectorToNext: _connectorSources('recovery-spacing'),
    scrollExtent: 2.2,
    transitionExtent: 0.8,
    linger: 0.4,
  ),
  ScrollWorldScene(
    id: 'spacing',
    title: 'Move as a pair',
    description:
        'Padlo measures the gap between partners, revealing when the middle is protected and when it is exposed.',
    poster: const AssetImage('assets/posters/spacing.webp'),
    reducedMotionImage: const AssetImage('assets/posters/spacing.webp'),
    sources: _sceneSources('spacing'),
    connectorToNext: _connectorSources('spacing-transition'),
    scrollExtent: 2.2,
    transitionExtent: 0.8,
    linger: 0.4,
  ),
  ScrollWorldScene(
    id: 'transition',
    title: 'Make the right transition',
    description:
        'Attack, hold, or recover. Turn one real match into a clear plan for the next one.',
    poster: const AssetImage('assets/posters/transition.webp'),
    reducedMotionImage: const AssetImage('assets/posters/transition.webp'),
    sources: _sceneSources('transition'),
    scrollExtent: 2.6,
    transitionExtent: 0,
    linger: 0.4,
    actions: <ScrollWorldAction>[
      ScrollWorldAction.custom(
        id: 'create-account',
        label: 'Create demo account',
        semanticLabel: 'Create a local Padlo demonstration account',
        style: ScrollWorldActionStyle.primary,
      ),
      ScrollWorldAction.replayReverse(
        id: 'replay-tour',
        label: 'Replay the tour',
        semanticLabel: 'Replay the Padlo positioning tour backwards',
        style: ScrollWorldActionStyle.secondary,
      ),
    ],
  ),
];

ScrollWorldSources _sceneSources(String name) => ScrollWorldSources(
  mobilePortrait: ScrollWorldSource.asset('assets/videos/$name-portrait.mp4'),
  mobileLandscape: ScrollWorldSource.asset('assets/videos/$name-landscape.mp4'),
  webStandard: ScrollWorldSource.asset('assets/videos/$name-landscape.mp4'),
  webHigh: ScrollWorldSource.asset('assets/videos/$name-landscape.mp4'),
);

ScrollWorldSources _connectorSources(String name) => ScrollWorldSources(
  mobilePortrait: ScrollWorldSource.asset('assets/videos/$name-portrait.mp4'),
  mobileLandscape: ScrollWorldSource.asset('assets/videos/$name-landscape.mp4'),
  webStandard: ScrollWorldSource.asset('assets/videos/$name-landscape.mp4'),
  webHigh: ScrollWorldSource.asset('assets/videos/$name-landscape.mp4'),
);

final class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

final class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = ScrollWorldController();
  String _sceneId = 'see-court';
  ScrollWorldMotionState _motion = ScrollWorldMotionState.idle;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continueToRegistration() async {
    await PadloScope.of(context).completeOnboarding();
    if (mounted) context.go('/register');
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      backgroundColor: PadloTokens.darkSurface,
      body: Stack(
        children: <Widget>[
          ScrollWorldView(
            scenes: _onboardingScenes,
            controller: _controller,
            configuration: const ScrollWorldConfiguration(
              preloadRadius: 1,
              smoothingFactor: 0.18,
              reverseReplayDuration: Duration(seconds: 10),
            ),
            theme: ScrollWorldTheme(
              backgroundColor: PadloTokens.darkSurface,
              overlayGradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0x220D1020),
                  Color(0x160D1020),
                  Color(0xEB0D1020),
                ],
                stops: <double>[0, 0.45, 1],
              ),
              progressActiveColor: PadloTokens.accent,
              progressInactiveColor: Color(0x55FFFFFF),
              overlayPadding: compact
                  ? const EdgeInsets.fromLTRB(20, 72, 56, 28)
                  : const EdgeInsets.fromLTRB(24, 96, 64, 52),
              overlayMaxWidth: 640,
              actionSpacing: 24,
            ),
            overlayBuilder: (context, scene, progress, visibility) =>
                _OnboardingOverlay(scene: scene, progress: progress),
            actionBuilder: (context, scene, action, onPressed) =>
                _OnboardingAction(action: action, onPressed: onPressed),
            onSceneChanged: (scene, index) {
              if (_sceneId != scene.id) setState(() => _sceneId = scene.id);
            },
            onMotionStateChanged: (motion) {
              if (_motion != motion) setState(() => _motion = motion);
            },
            onAction: (scene, action) async {
              if (action.id == 'create-account') {
                await _continueToRegistration();
              }
            },
            onError: (error) => debugPrint('Padlo onboarding: $error'),
          ),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(24, 20, 72, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const PadloLogo(light: true, height: 32),
                const Spacer(),
                TextButton(
                  onPressed: _continueToRegistration,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Skip tour'),
                ),
              ],
            ),
          ),
          if (_motion == ScrollWorldMotionState.replayingReverse)
            const SafeArea(
              minimum: EdgeInsets.only(top: 64),
              child: Align(
                alignment: Alignment.topCenter,
                child: _ReplayStatus(),
              ),
            ),
        ],
      ),
    );
  }
}

final class _ReplayStatus extends StatelessWidget {
  const _ReplayStatus();

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Replaying the tour backwards',
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: PadloTokens.darkSurface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(PadloTokens.radiusSmall),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: PadloTokens.space16,
          vertical: PadloTokens.space8,
        ),
        child: Text(
          'REPLAYING BACK TO THE START',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
      ),
    ),
  );
}

final class _OnboardingAction extends StatelessWidget {
  const _OnboardingAction({required this.action, required this.onPressed});

  final ScrollWorldAction action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = action.style == ScrollWorldActionStyle.primary;
    final icon = action.intent == ScrollWorldActionIntent.replayReverse
        ? Icons.replay_rounded
        : Icons.arrow_forward_rounded;
    final child = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(action.label),
          const SizedBox(width: PadloTokens.space8),
          Icon(icon, size: PadloTokens.space20),
        ],
      ),
    );
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: action.semanticLabel ?? action.label,
      child: primary
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: PadloTokens.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: PadloTokens.space16,
                ),
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
                padding: const EdgeInsets.symmetric(
                  horizontal: PadloTokens.space16,
                ),
              ),
              child: child,
            ),
    );
  }
}

final class _OnboardingOverlay extends StatelessWidget {
  const _OnboardingOverlay({required this.scene, required this.progress});

  final ScrollWorldScene scene;
  final double progress;

  static const _numbers = <String, String>{
    'see-court': '01',
    'net-depth': '02',
    'recovery': '03',
    'spacing': '04',
    'transition': '05',
  };

  @override
  Widget build(BuildContext context) {
    final portrait = MediaQuery.sizeOf(context).width < 600;
    final showScrollCue = scene.id == 'see-court'
        ? ((0.42 - progress) / 0.18).clamp(0.0, 1.0)
        : 0.0;
    return Semantics(
      container: true,
      header: true,
      label: '${scene.title}. ${scene.description}',
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: portrait ? 430 : 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _numbers[scene.id]!,
                  style: const TextStyle(
                    color: PadloTokens.accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.7,
                  ),
                ),
                const SizedBox(width: PadloTokens.space12),
                const SizedBox(
                  width: 38,
                  child: Divider(color: PadloTokens.accent, thickness: 2),
                ),
                const SizedBox(width: PadloTokens.space12),
                const Flexible(
                  child: Text(
                    'POSITIONING, MADE VISIBLE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.25,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: PadloTokens.space16),
            Text(
              scene.title!,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: Colors.white,
                fontSize: portrait ? 38 : 58,
              ),
            ),
            const SizedBox(height: PadloTokens.space16),
            Text(
              scene.description!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFFE4E7F2),
                fontSize: portrait ? 15 : 18,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
            if (scene.id == 'see-court') ...<Widget>[
              const SizedBox(height: PadloTokens.space24),
              Opacity(
                opacity: showScrollCue,
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.south_rounded, color: PadloTokens.accent),
                      SizedBox(width: PadloTokens.space8),
                      Text(
                        'SCROLL TO READ THE COURT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
