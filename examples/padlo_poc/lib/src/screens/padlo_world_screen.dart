import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:scroll_world/scroll_world.dart';

import '../app.dart';
import '../models/demo_models.dart';
import '../theme/padlo_theme.dart';
import '../widgets/padlo_primitives.dart';

const _sceneIds = <String>[
  'first-serve',
  'positioning-lab',
  'decision-gate',
  'player-tunnel',
  'player-setup',
  'clubhouse',
  'analysis-court',
  'report-vault',
  'replay-arena',
  'profile-locker',
];

final _worldScenes = <ScrollWorldScene>[
  _worldScene(
    id: 'first-serve',
    title: 'Read the point before it happens',
    extent: 2.1,
    interaction: const ScrollWorldInteractionRegion(start: 0.18, end: 0.92),
  ),
  _worldScene(
    id: 'positioning-lab',
    title: 'Claim the pressure zone',
    extent: 2.3,
    interaction: const ScrollWorldInteractionRegion(start: 0.38, end: 0.92),
  ),
  _worldScene(
    id: 'decision-gate',
    title: 'Make the next move',
    extent: 2.2,
    interaction: const ScrollWorldInteractionRegion(start: 0.34, end: 0.94),
  ),
  _worldScene(
    id: 'player-tunnel',
    title: 'Turn movement into a signal',
    extent: 1.7,
    interaction: const ScrollWorldInteractionRegion(start: 0.24, end: 0.92),
  ),
  _worldScene(
    id: 'player-setup',
    title: 'Build your player profile',
    extent: 2.6,
    gateAt: 0.74,
    interaction: const ScrollWorldInteractionRegion(start: 0.36, end: 1),
  ),
  _worldScene(
    id: 'clubhouse',
    title: 'Your positioning room',
    extent: 2.4,
    interaction: const ScrollWorldInteractionRegion(start: 0.3, end: 0.96),
  ),
  _worldScene(
    id: 'analysis-court',
    title: 'Scan the match',
    extent: 2.5,
    interaction: const ScrollWorldInteractionRegion(start: 0.28, end: 0.96),
  ),
  _worldScene(
    id: 'report-vault',
    title: 'Every match leaves a pattern',
    extent: 2.35,
    interaction: const ScrollWorldInteractionRegion(start: 0.28, end: 0.96),
  ),
  _worldScene(
    id: 'replay-arena',
    title: 'Step back inside the match',
    extent: 3.2,
    interaction: const ScrollWorldInteractionRegion(start: 0.18, end: 1),
  ),
  _worldScene(
    id: 'profile-locker',
    title: 'Prepare the next match',
    extent: 2.4,
    transitionExtent: 0,
    interaction: const ScrollWorldInteractionRegion(start: 0.24, end: 1),
  ),
];

ScrollWorldScene _worldScene({
  required String id,
  required String title,
  required double extent,
  required ScrollWorldInteractionRegion interaction,
  double transitionExtent = 0.16,
  double? gateAt,
}) => ScrollWorldScene(
  id: id,
  title: title,
  sources: ScrollWorldSources(
    mobilePortrait: ScrollWorldSource.asset('assets/videos/$id-portrait.mp4'),
    mobileLandscape: ScrollWorldSource.asset('assets/videos/$id-landscape.mp4'),
    webStandard: ScrollWorldSource.asset('assets/videos/$id-landscape.mp4'),
    webHigh: ScrollWorldSource.asset('assets/videos/$id-landscape.mp4'),
  ),
  poster: AssetImage('assets/posters/$id.webp'),
  reducedMotionImage: AssetImage('assets/posters/$id.webp'),
  scrollExtent: extent,
  transitionExtent: transitionExtent,
  linger: 0.45,
  interactionRegion: interaction,
  gateAt: gateAt,
  overlayAnimation: ScrollWorldOverlayAnimation.none,
);

final class PadloWorldScreen extends StatefulWidget {
  const PadloWorldScreen({
    required this.routeLocation,
    required this.routeChild,
    super.key,
  });

  final String routeLocation;
  final Widget routeChild;

  @override
  State<PadloWorldScreen> createState() => _PadloWorldScreenState();
}

final class _PadloWorldScreenState extends State<PadloWorldScreen> {
  final _journey = ScrollWorldController();
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController(text: 'Luka');
  final _lastName = TextEditingController(text: 'Novak');
  final _email = TextEditingController(text: 'luka.novak@example.com');

  PlayerLevel _level = PlayerLevel.intermediate;
  CourtSide _side = CourtSide.right;
  PositioningFocus _focus = PositioningFocus.recoveryTiming;
  String? _positioningChoice;
  String? _decisionChoice;
  int? _replayChoice;
  bool _submitting = false;
  bool _analysisRunning = false;
  String _activeSceneId = 'first-serve';
  String? _routingToScene;
  ScrollWorldMotionState _motionState = ScrollWorldMotionState.idle;

  Uri get _routeUri => Uri.parse(widget.routeLocation);

  String get _targetSceneId {
    final path = _routeUri.path;
    if (path == '/register') return 'player-setup';
    if (path == '/app/home') return 'clubhouse';
    if (path == '/app/record') return 'analysis-court';
    if (path == '/app/reports') return 'report-vault';
    if (path.startsWith('/app/reports/')) return 'replay-arena';
    if (path == '/app/profile') return 'profile-locker';
    return 'first-serve';
  }

  @override
  void initState() {
    super.initState();
    _activeSceneId = _targetSceneId;
  }

  @override
  void didUpdateWidget(PadloWorldScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeLocation == widget.routeLocation) return;
    final target = _targetSceneId;
    final reportId = _reportIdFromRoute();
    if (reportId != null) {
      unawaited(PadloScope.of(context).selectReport(reportId));
    }
    if (target == _activeSceneId || !_journey.isAttached) return;
    _routingToScene = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_journey.isAttached) return;
      unawaited(
        _journey.animateToScene(
          target,
          sceneProgress: _targetProgress(target),
          duration: const Duration(milliseconds: 1150),
          curve: Curves.easeInOutSine,
        ),
      );
    });
  }

  String? _reportIdFromRoute() {
    final segments = _routeUri.pathSegments;
    if (segments.length == 3 &&
        segments[0] == 'app' &&
        segments[1] == 'reports') {
      return segments[2];
    }
    return null;
  }

  double _targetProgress(String sceneId) => switch (sceneId) {
    'player-setup' => 0.7,
    'clubhouse' => 0.56,
    'analysis-court' => 0.52,
    'report-vault' => 0.52,
    'replay-arena' => 0.28,
    'profile-locker' => 0.58,
    _ => 0.12,
  };

  @override
  void dispose() {
    _journey.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final store = PadloScope.of(context);
    setState(() => _submitting = true);
    await store.register(
      DemoPlayerProfile(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        level: _level,
        preferredSide: _side,
        focus: _focus,
      ),
    );
    if (!mounted) return;
    _journey.openGate('player-setup');
    setState(() => _submitting = false);
    final returnPath = _routeUri.queryParameters['from'];
    _goTo(returnPath?.startsWith('/app/') == true ? returnPath! : '/app/home');
  }

  Future<void> _runAnalysis() async {
    if (_analysisRunning) return;
    final store = PadloScope.of(context);
    setState(() => _analysisRunning = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await store.markReportGenerated();
    if (mounted) setState(() => _analysisRunning = false);
  }

  void _goTo(String path) {
    _journey.cancelMotion();
    if (_routeUri.path != path) context.go(path);
  }

  void _handleSceneChanged(ScrollWorldScene scene, int index) {
    if (_activeSceneId != scene.id && mounted) {
      setState(() => _activeSceneId = scene.id);
    }
    unawaited(PadloScope.of(context).setWorldCheckpoint(scene.id));
    if (_routingToScene != null && _routingToScene != scene.id) return;
    _routingToScene = null;
    final store = PadloScope.of(context);
    final path = switch (scene.id) {
      'first-serve' ||
      'positioning-lab' ||
      'decision-gate' ||
      'player-tunnel' => '/onboarding',
      'player-setup' => '/register',
      'clubhouse' => '/app/home',
      'analysis-court' => '/app/record',
      'report-vault' => '/app/reports',
      'replay-arena' => '/app/reports/${store.selectedReportId}',
      'profile-locker' => '/app/profile',
      _ => '/onboarding',
    };
    if (_routeUri.path != path) context.go(path);
  }

  Future<void> _resetProfile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _ResetWorldDialog(),
    );
    if (confirmed != true || !mounted) return;
    await PadloScope.of(context).reset();
    if (!mounted) return;
    _journey.resetGate('player-setup');
    _goTo('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final store = PadloScope.of(context);
    final initialScene = _targetSceneId;
    return Scaffold(
      backgroundColor: PadloTokens.darkSurface,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ScrollWorldView(
            scenes: _worldScenes,
            controller: _journey,
            initialSceneId: initialScene,
            initialSceneProgress: _targetProgress(initialScene),
            openedGateIds: store.isRegistered
                ? const <String>{'player-setup'}
                : const <String>{},
            configuration: const ScrollWorldConfiguration(
              preloadRadius: 1,
              smoothingFactor: 0.18,
              seamFadeFraction: 0.08,
              showProgressNavigation: false,
              navigationDuration: Duration(milliseconds: 1150),
              reverseReplayDuration: Duration(seconds: 12),
            ),
            theme: const ScrollWorldTheme(
              backgroundColor: PadloTokens.darkSurface,
              overlayGradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0x2E080B15),
                  Color(0x08080B15),
                  Color(0xA8080B15),
                ],
                stops: <double>[0, 0.5, 1],
              ),
              overlayPadding: EdgeInsets.zero,
              overlayMaxWidth: double.infinity,
            ),
            overlayBuilder: (context, scene, progress, visibility) =>
                const SizedBox.shrink(),
            sceneContentBuilder: (context, frame) =>
                _buildScene(context, frame),
            onSceneChanged: _handleSceneChanged,
            onMotionStateChanged: (state) {
              if (_motionState != state && mounted) {
                setState(() => _motionState = state);
              }
            },
            onError: (error) => debugPrint('Padlo world playback: $error'),
          ),
          _WorldHud(
            activeSceneId: _activeSceneId,
            motionState: _motionState,
            registered: store.isRegistered,
            onPlayerSetup: () => _goTo('/register'),
            onReplay: () => unawaited(_journey.replayReverse()),
          ),
          Offstage(offstage: true, child: widget.routeChild),
        ],
      ),
    );
  }

  Widget _buildScene(BuildContext context, ScrollWorldSceneFrame frame) {
    final store = PadloScope.of(context);
    return switch (frame.scene.id) {
      'first-serve' => _FirstServeScene(frame: frame),
      'positioning-lab' => _PositioningLabScene(
        frame: frame,
        selected: _positioningChoice,
        onSelected: (value) {
          setState(() => _positioningChoice = value);
          if (value == 'Pressure zone') {
            unawaited(store.completeChallenge('pressure-zone'));
          }
        },
      ),
      'decision-gate' => _DecisionScene(
        frame: frame,
        selected: _decisionChoice,
        onSelected: (value) {
          setState(() => _decisionChoice = value);
          if (value == 'Recover') {
            unawaited(store.completeChallenge('recover-first'));
          }
        },
      ),
      'player-tunnel' => _TunnelScene(
        frame: frame,
        missionScore: store.missionScore,
      ),
      'player-setup' => _buildPlayerSetup(context, frame),
      'clubhouse' => _HubScene(
        frame: frame,
        profile: store.profile,
        missionScore: store.missionScore,
        reportReady: store.hasGeneratedReport,
        onNavigate: _goTo,
      ),
      'analysis-court' => _AnalysisScene(
        frame: frame,
        running: _analysisRunning,
        ready: store.hasGeneratedReport,
        onAnalyze: _runAnalysis,
        onOpenReport: () => _goTo('/app/reports/${featuredReport.id}'),
      ),
      'report-vault' => _ReportVaultScene(
        frame: frame,
        reports: store.reports,
        selectedReportId: store.selectedReportId,
        onOpen: (report) async {
          await store.selectReport(report.id);
          if (mounted) _goTo('/app/reports/${report.id}');
        },
      ),
      'replay-arena' => _ReplayArenaScene(
        frame: frame,
        report: store.reportById(store.selectedReportId) ?? featuredReport,
        selectedChoice: _replayChoice,
        onChoice: (index) {
          setState(() => _replayChoice = index);
          unawaited(store.completeChallenge('replay-moment-$index'));
        },
        onVault: () => _goTo('/app/reports'),
      ),
      'profile-locker' => _ProfileLockerScene(
        frame: frame,
        profile: store.profile,
        challenges: store.completedChallenges.length,
        onHub: () => _goTo('/app/home'),
        onReplay: () => unawaited(_journey.replayReverse()),
        onReset: _resetProfile,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildPlayerSetup(BuildContext context, ScrollWorldSceneFrame frame) =>
      _PlayerSetupScene(
        frame: frame,
        formKey: _formKey,
        firstName: _firstName,
        lastName: _lastName,
        email: _email,
        level: _level,
        side: _side,
        focus: _focus,
        submitting: _submitting,
        onLevel: (value) => setState(() => _level = value),
        onSide: (value) => setState(() => _side = value),
        onFocus: (value) => setState(() => _focus = value),
        onSubmit: _submitProfile,
      );
}

final class _WorldHud extends StatelessWidget {
  const _WorldHud({
    required this.activeSceneId,
    required this.motionState,
    required this.registered,
    required this.onPlayerSetup,
    required this.onReplay,
  });

  final String activeSceneId;
  final ScrollWorldMotionState motionState;
  final bool registered;
  final VoidCallback onPlayerSetup;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final sceneIndex = math.max(0, _sceneIds.indexOf(activeSceneId));
    return IgnorePointer(
      ignoring: false,
      child: SafeArea(
        minimum: EdgeInsets.all(
          compact ? PadloTokens.space16 : PadloTokens.space24,
        ),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                const PadloLogo(light: true, height: 30),
                const Spacer(),
                _HudStatus(
                  label: '${sceneIndex + 1} / ${_sceneIds.length}',
                  active: motionState != ScrollWorldMotionState.idle,
                ),
                const SizedBox(width: PadloTokens.space8),
                if (!compact)
                  OutlinedButton.icon(
                    onPressed: registered ? onReplay : onPlayerSetup,
                    icon: Icon(
                      registered ? Icons.replay_rounded : Icons.badge_outlined,
                    ),
                    label: Text(registered ? 'Replay world' : 'Player setup'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomLeft,
              child: _HudStatus(
                label: 'PROOF OF CONCEPT · SIMULATED DATA',
                icon: Icons.science_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _HudStatus extends StatelessWidget {
  const _HudStatus({this.icon, required this.label, this.active = false});

  final IconData? icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: PadloTokens.darkSurface.withValues(alpha: 0.78),
        border: Border.all(color: active ? PadloTokens.accent : Colors.white24),
        borderRadius: BorderRadius.circular(PadloTokens.radiusSmall),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PadloTokens.space12,
          vertical: PadloTokens.space8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: PadloTokens.space8),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

final class _FirstServeScene extends StatelessWidget {
  const _FirstServeScene({required this.frame});

  final ScrollWorldSceneFrame frame;

  @override
  Widget build(BuildContext context) => _SceneStage(
    frame: frame,
    alignment: Alignment.bottomLeft,
    child: _NarrativePanel(
      eyebrow: 'MISSION 01 · LJUBLJANA 19:30',
      title: 'Read the point before it happens.',
      body:
          'Follow the ball into the rally. Padlo turns invisible positioning decisions into a court you can read.',
      footer: Row(
        mainAxisSize: MainAxisSize.min,
        children: const <Widget>[
          Icon(Icons.south_rounded, color: PadloTokens.accent),
          SizedBox(width: PadloTokens.space8),
          Text('SCROLL TO ENTER THE ARENA'),
        ],
      ),
    ),
  );
}

final class _PositioningLabScene extends StatelessWidget {
  const _PositioningLabScene({
    required this.frame,
    required this.selected,
    required this.onSelected,
  });

  final ScrollWorldSceneFrame frame;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => _SceneStage(
    frame: frame,
    alignment: Alignment.centerRight,
    child: _WorldPanel(
      semanticLabel: 'Positioning zone challenge',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const _PanelEyebrow('COURT CHALLENGE · NET DEPTH'),
          const SizedBox(height: PadloTokens.space12),
          const Text(
            'Where does your pair keep pressure?',
            style: _WorldText.title,
          ),
          const SizedBox(height: PadloTokens.space12),
          const Text(
            'Choose the zone that protects the middle without crowding the net.',
            style: _WorldText.body,
          ),
          const SizedBox(height: PadloTokens.space20),
          Wrap(
            spacing: PadloTokens.space8,
            runSpacing: PadloTokens.space8,
            children: <Widget>[
              for (final choice in const <String>[
                'Back glass',
                'Pressure zone',
                'Net tape',
              ])
                _MissionChoice(
                  label: choice,
                  selected: selected == choice,
                  correct: selected == choice && choice == 'Pressure zone',
                  onPressed: () => onSelected(choice),
                ),
            ],
          ),
          if (selected != null) ...<Widget>[
            const SizedBox(height: PadloTokens.space16),
            _FeedbackLine(
              success: selected == 'Pressure zone',
              text: selected == 'Pressure zone'
                  ? 'Signal locked: 2.5–3.5 m keeps both players dangerous.'
                  : 'That position gives away space. Read the blue pressure band.',
            ),
          ],
        ],
      ),
    ),
  );
}

final class _DecisionScene extends StatelessWidget {
  const _DecisionScene({
    required this.frame,
    required this.selected,
    required this.onSelected,
  });

  final ScrollWorldSceneFrame frame;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => _SceneStage(
    frame: frame,
    alignment: Alignment.bottomLeft,
    child: _WorldPanel(
      semanticLabel: 'Transition decision challenge',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const _PanelEyebrow('LIVE DECISION · AFTER THE BANDEJA'),
          const SizedBox(height: PadloTokens.space12),
          const Text(
            'The lob is still rising. What comes next?',
            style: _WorldText.title,
          ),
          const SizedBox(height: PadloTokens.space20),
          Wrap(
            spacing: PadloTokens.space8,
            runSpacing: PadloTokens.space8,
            children: <Widget>[
              for (final choice in const <String>['Attack', 'Hold', 'Recover'])
                _MissionChoice(
                  label: choice,
                  selected: selected == choice,
                  correct: selected == choice && choice == 'Recover',
                  onPressed: () => onSelected(choice),
                ),
            ],
          ),
          if (selected != null) ...<Widget>[
            const SizedBox(height: PadloTokens.space16),
            _FeedbackLine(
              success: selected == 'Recover',
              text: selected == 'Recover'
                  ? 'Correct. First step back, find your partner, then rebuild pressure.'
                  : 'Too early. The middle opens before your pair is balanced.',
            ),
          ],
        ],
      ),
    ),
  );
}

final class _TunnelScene extends StatelessWidget {
  const _TunnelScene({required this.frame, required this.missionScore});

  final ScrollWorldSceneFrame frame;
  final int missionScore;

  @override
  Widget build(BuildContext context) => _SceneStage(
    frame: frame,
    alignment: Alignment.center,
    maxWidth: 520,
    child: _WorldPanel(
      semanticLabel: 'Player tunnel progress',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.bolt_rounded, color: PadloTokens.accent, size: 34),
          const SizedBox(height: PadloTokens.space16),
          Text('$missionScore tactical signal', style: _WorldText.metric),
          const SizedBox(height: PadloTokens.space8),
          const Text(
            'Your court reads are becoming a player profile. Continue into the locker terminal.',
            textAlign: TextAlign.center,
            style: _WorldText.body,
          ),
          const SizedBox(height: PadloTokens.space20),
          const LinearProgressIndicator(
            value: 0.64,
            backgroundColor: Colors.white12,
            color: PadloTokens.accent,
          ),
        ],
      ),
    ),
  );
}

final class _PlayerSetupScene extends StatelessWidget {
  const _PlayerSetupScene({
    required this.frame,
    required this.formKey,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.level,
    required this.side,
    required this.focus,
    required this.submitting,
    required this.onLevel,
    required this.onSide,
    required this.onFocus,
    required this.onSubmit,
  });

  final ScrollWorldSceneFrame frame;
  final GlobalKey<FormState> formKey;
  final TextEditingController firstName;
  final TextEditingController lastName;
  final TextEditingController email;
  final PlayerLevel level;
  final CourtSide side;
  final PositioningFocus focus;
  final bool submitting;
  final ValueChanged<PlayerLevel> onLevel;
  final ValueChanged<CourtSide> onSide;
  final ValueChanged<PositioningFocus> onFocus;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => _SceneStage(
    frame: frame,
    alignment: Alignment.centerRight,
    maxWidth: 620,
    child: _WorldPanel(
      semanticLabel: 'Local player setup terminal',
      padding: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.76,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PadloTokens.space24),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const _PanelEyebrow('PLAYER TERMINAL · LOCAL DEMO'),
                const SizedBox(height: PadloTokens.space12),
                const Text(
                  'Unlock your positioning room.',
                  style: _WorldText.title,
                ),
                const SizedBox(height: PadloTokens.space8),
                const Text(
                  'The camera waits here until your local player profile is ready.',
                  style: _WorldText.body,
                ),
                const SizedBox(height: PadloTokens.space20),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _WorldField(
                        key: const Key('first-name-field'),
                        controller: firstName,
                        label: 'First name',
                        validator: _validateName,
                      ),
                    ),
                    const SizedBox(width: PadloTokens.space12),
                    Expanded(
                      child: _WorldField(
                        key: const Key('last-name-field'),
                        controller: lastName,
                        label: 'Last name',
                        validator: _validateName,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: PadloTokens.space12),
                _WorldField(
                  key: const Key('email-field'),
                  controller: email,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: PadloTokens.space12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final levelField = _WorldDropdown<PlayerLevel>(
                      label: 'Level',
                      value: level,
                      values: PlayerLevel.values,
                      onChanged: onLevel,
                    );
                    final sideField = _WorldDropdown<CourtSide>(
                      label: 'Court side',
                      value: side,
                      values: CourtSide.values,
                      onChanged: onSide,
                    );
                    if (constraints.maxWidth < 480) {
                      return Column(
                        children: <Widget>[
                          levelField,
                          const SizedBox(height: PadloTokens.space12),
                          sideField,
                        ],
                      );
                    }
                    return Row(
                      children: <Widget>[
                        Expanded(child: levelField),
                        const SizedBox(width: PadloTokens.space12),
                        Expanded(child: sideField),
                      ],
                    );
                  },
                ),
                const SizedBox(height: PadloTokens.space16),
                const Text('Positioning focus', style: _WorldText.label),
                const SizedBox(height: PadloTokens.space8),
                Wrap(
                  spacing: PadloTokens.space8,
                  runSpacing: PadloTokens.space8,
                  children: <Widget>[
                    for (final value in PositioningFocus.values)
                      ChoiceChip(
                        label: Text(enumLabel(value)),
                        selected: focus == value,
                        onSelected: (selected) {
                          if (selected) onFocus(value);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: PadloTokens.space20),
                FilledButton.icon(
                  key: const Key('create-demo-account'),
                  onPressed: submitting ? null : onSubmit,
                  icon: submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_open_rounded),
                  label: Text(
                    submitting ? 'Opening clubhouse…' : 'Enter the clubhouse',
                  ),
                ),
                const SizedBox(height: PadloTokens.space12),
                const Text(
                  'No password · No upload · Nothing leaves this device',
                  style: _WorldText.caption,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

final class _HubScene extends StatelessWidget {
  const _HubScene({
    required this.frame,
    required this.profile,
    required this.missionScore,
    required this.reportReady,
    required this.onNavigate,
  });

  final ScrollWorldSceneFrame frame;
  final DemoPlayerProfile? profile;
  final int missionScore;
  final bool reportReady;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => _SceneStage(
    frame: frame,
    alignment: Alignment.centerLeft,
    maxWidth: 720,
    child: _WorldPanel(
      semanticLabel: 'Padlo clubhouse hub',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const _PanelEyebrow('CLUBHOUSE HUB · PLAYER ONLINE'),
          const SizedBox(height: PadloTokens.space12),
          Text(
            'Dobrodošel, ${profile?.firstName ?? 'Luka'}.',
            style: _WorldText.title,
          ),
          const SizedBox(height: PadloTokens.space8),
          Text(
            '${72 + missionScore ~/ 8} positioning score · Recovery timing is your next edge.',
            style: _WorldText.body,
          ),
          const SizedBox(height: PadloTokens.space20),
          LayoutBuilder(
            builder: (context, constraints) {
              final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: constraints.maxWidth < 520 ? 2 : 4,
                mainAxisSpacing: PadloTokens.space8,
                crossAxisSpacing: PadloTokens.space8,
                childAspectRatio: largeText
                    ? 0.65
                    : constraints.maxWidth < 520
                    ? 1.65
                    : 1.15,
                children: <Widget>[
                  _PortalTile(
                    icon: Icons.radar_rounded,
                    label: 'Analysis court',
                    status: reportReady ? 'Scan complete' : 'Ready',
                    onPressed: () => onNavigate('/app/record'),
                  ),
                  _PortalTile(
                    icon: Icons.view_in_ar_rounded,
                    label: 'Report vault',
                    status: '3 matches',
                    onPressed: () => onNavigate('/app/reports'),
                  ),
                  _PortalTile(
                    icon: Icons.sports_tennis_rounded,
                    label: 'Replay arena',
                    status: '72 score',
                    onPressed: () =>
                        onNavigate('/app/reports/${featuredReport.id}'),
                  ),
                  _PortalTile(
                    icon: Icons.checkroom_rounded,
                    label: 'Player locker',
                    status: '${missionScore ~/ 8} signals',
                    onPressed: () => onNavigate('/app/profile'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

final class _AnalysisScene extends StatelessWidget {
  const _AnalysisScene({
    required this.frame,
    required this.running,
    required this.ready,
    required this.onAnalyze,
    required this.onOpenReport,
  });

  final ScrollWorldSceneFrame frame;
  final bool running;
  final bool ready;
  final VoidCallback onAnalyze;
  final VoidCallback onOpenReport;

  @override
  Widget build(BuildContext context) {
    final phase = frame.rawProgress < 0.38
        ? 'CALIBRATING COURT'
        : frame.rawProgress < 0.68
        ? 'TRACKING FOUR PLAYERS'
        : 'POSITIONING MAP READY';
    return _SceneStage(
      frame: frame,
      alignment: Alignment.bottomRight,
      child: _WorldPanel(
        semanticLabel: 'Simulated match analysis court',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _PanelEyebrow(phase),
            const SizedBox(height: PadloTokens.space12),
            Text(
              ready
                  ? 'Your Ljubljana report is ready.'
                  : 'Turn one rally into a court map.',
              style: _WorldText.title,
            ),
            const SizedBox(height: PadloTokens.space8),
            const Text(
              'This deterministic demonstration analyzes local simulated motion. No video is uploaded.',
              style: _WorldText.body,
            ),
            const SizedBox(height: PadloTokens.space16),
            LinearProgressIndicator(
              value: running ? null : frame.rawProgress,
              backgroundColor: Colors.white12,
              color: ready ? PadloTokens.success : PadloTokens.accent,
            ),
            const SizedBox(height: PadloTokens.space20),
            FilledButton.icon(
              key: const Key('analyze-demo-match'),
              onPressed: running
                  ? null
                  : ready
                  ? onOpenReport
                  : onAnalyze,
              icon: Icon(
                ready ? Icons.arrow_forward_rounded : Icons.radar_rounded,
              ),
              label: Text(
                ready ? 'Enter the replay arena' : 'Analyze demo rally',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ReportVaultScene extends StatelessWidget {
  const _ReportVaultScene({
    required this.frame,
    required this.reports,
    required this.selectedReportId,
    required this.onOpen,
  });

  final ScrollWorldSceneFrame frame;
  final List<GameReport> reports;
  final String selectedReportId;
  final ValueChanged<GameReport> onOpen;

  @override
  Widget build(BuildContext context) => _SceneStage(
    frame: frame,
    alignment: Alignment.center,
    maxWidth: 900,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const _PanelEyebrow('REPORT VAULT · SELECT A MATCH TOKEN'),
        const SizedBox(height: PadloTokens.space12),
        const Text('Every match leaves a pattern.', style: _WorldText.title),
        const SizedBox(height: PadloTokens.space20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: PadloTokens.space16,
          runSpacing: PadloTokens.space16,
          children: <Widget>[
            for (final report in reports)
              _MatchToken(
                report: report,
                selected: selectedReportId == report.id,
                onPressed: () => onOpen(report),
              ),
          ],
        ),
      ],
    ),
  );
}

final class _ReplayArenaScene extends StatelessWidget {
  const _ReplayArenaScene({
    required this.frame,
    required this.report,
    required this.selectedChoice,
    required this.onChoice,
    required this.onVault,
  });

  final ScrollWorldSceneFrame frame;
  final GameReport report;
  final int? selectedChoice;
  final ValueChanged<int> onChoice;
  final VoidCallback onVault;

  @override
  Widget build(BuildContext context) {
    final momentIndex = math.min(
      report.moments.length - 1,
      (frame.rawProgress * report.moments.length).floor(),
    );
    final moment = report.moments[momentIndex];
    return _SceneStage(
      frame: frame,
      alignment: Alignment.bottomLeft,
      maxWidth: 760,
      child: _WorldPanel(
        semanticLabel: '${report.city} tactical replay',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _PanelEyebrow(
              '${report.city.toUpperCase()} · ${report.dateLabel.toUpperCase()} · ${_durationLabel(moment.time)}',
            ),
            const SizedBox(height: PadloTokens.space12),
            Text(moment.title, style: _WorldText.title),
            const SizedBox(height: PadloTokens.space8),
            Text(moment.description, style: _WorldText.body),
            const SizedBox(height: PadloTokens.space16),
            SizedBox(
              height: 120,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _TacticalCourt(
                      report: report,
                      progress: frame.rawProgress,
                    ),
                  ),
                  const SizedBox(width: PadloTokens.space16),
                  _ScoreBeacon(score: report.score, change: report.change),
                ],
              ),
            ),
            const SizedBox(height: PadloTokens.space16),
            const Text('Your call?', style: _WorldText.label),
            const SizedBox(height: PadloTokens.space8),
            Wrap(
              spacing: PadloTokens.space8,
              runSpacing: PadloTokens.space8,
              children: <Widget>[
                for (var index = 0; index < 3; index++)
                  _MissionChoice(
                    label: const <String>[
                      'Advance',
                      'Hold shape',
                      'Recover together',
                    ][index],
                    selected: selectedChoice == index,
                    correct: selectedChoice == index && index == 2,
                    onPressed: () => onChoice(index),
                  ),
              ],
            ),
            if (selectedChoice != null) ...<Widget>[
              const SizedBox(height: PadloTokens.space12),
              _FeedbackLine(
                success: selectedChoice == 2,
                text: selectedChoice == 2
                    ? report.plan.cue
                    : 'Replay the player paths: the pair must reconnect before advancing.',
              ),
            ],
            const SizedBox(height: PadloTokens.space12),
            TextButton.icon(
              onPressed: onVault,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Return to report vault'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ProfileLockerScene extends StatelessWidget {
  const _ProfileLockerScene({
    required this.frame,
    required this.profile,
    required this.challenges,
    required this.onHub,
    required this.onReplay,
    required this.onReset,
  });

  final ScrollWorldSceneFrame frame;
  final DemoPlayerProfile? profile;
  final int challenges;
  final VoidCallback onHub;
  final VoidCallback onReplay;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => _SceneStage(
    frame: frame,
    alignment: Alignment.centerRight,
    child: _WorldPanel(
      semanticLabel: 'Player profile locker',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const _PanelEyebrow('PROFILE LOCKER · NEXT MATCH PLAN'),
          const SizedBox(height: PadloTokens.space12),
          Text(profile?.fullName ?? 'Luka Novak', style: _WorldText.title),
          const SizedBox(height: PadloTokens.space8),
          Text(
            '${enumLabel(profile?.level ?? PlayerLevel.intermediate)} · ${enumLabel(profile?.preferredSide ?? CourtSide.right)} side',
            style: _WorldText.body,
          ),
          const SizedBox(height: PadloTokens.space20),
          _FeedbackLine(
            success: true,
            text:
                '$challenges tactical signals unlocked · Recovery timing focus active',
          ),
          const SizedBox(height: PadloTokens.space16),
          const Text('NEXT MATCH CUE', style: _WorldText.caption),
          const SizedBox(height: PadloTokens.space8),
          const Text(
            'Hit. First step back. Find your partner.',
            style: _WorldText.label,
          ),
          const SizedBox(height: PadloTokens.space20),
          Wrap(
            spacing: PadloTokens.space8,
            runSpacing: PadloTokens.space8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: onHub,
                icon: const Icon(Icons.hub_outlined),
                label: const Text('Return to hub'),
              ),
              OutlinedButton.icon(
                onPressed: onReplay,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Replay world'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
              ),
              TextButton(
                onPressed: onReset,
                style: TextButton.styleFrom(
                  foregroundColor: PadloTokens.accent,
                ),
                child: const Text('Reset local demo'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

final class _SceneStage extends StatelessWidget {
  const _SceneStage({
    required this.frame,
    required this.alignment,
    required this.child,
    this.maxWidth = 650,
  });

  final ScrollWorldSceneFrame frame;
  final Alignment alignment;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final enter = Curves.easeOutCubic.transform(
      ((frame.rawProgress - 0.08) / 0.34).clamp(0.0, 1.0),
    );
    final horizontal = alignment.x == 0 ? 0.0 : (1 - enter) * 72 * alignment.x;
    return SafeArea(
      minimum: EdgeInsets.fromLTRB(
        compact ? PadloTokens.space16 : PadloTokens.space48,
        compact ? PadloTokens.space64 : 88,
        compact ? PadloTokens.space16 : PadloTokens.space48,
        compact ? PadloTokens.space64 : PadloTokens.space48,
      ),
      child: Align(
        alignment: compact ? Alignment.bottomCenter : alignment,
        child: Transform.translate(
          offset: frame.reducedMotion ? Offset.zero : Offset(horizontal, 0),
          child: Transform.scale(
            scale: frame.reducedMotion ? 1 : 0.94 + enter * 0.06,
            alignment: alignment,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: compact
                  ? SizedBox(width: double.infinity, child: child)
                  : child,
            ),
          ),
        ),
      ),
    );
  }
}

final class _WorldPanel extends StatelessWidget {
  const _WorldPanel({
    required this.child,
    required this.semanticLabel,
    this.padding = const EdgeInsets.all(PadloTokens.space24),
  });

  final Widget child;
  final String semanticLabel;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: semanticLabel,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: PadloTokens.darkSurface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(PadloTokens.radiusMedium),
        border: Border.all(
          color: PadloTokens.primarySoft.withValues(alpha: 0.6),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: PadloTokens.primary.withValues(alpha: 0.24),
            blurRadius: PadloTokens.space32,
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    ),
  );
}

final class _NarrativePanel extends StatelessWidget {
  const _NarrativePanel({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.footer,
  });

  final String eyebrow;
  final String title;
  final String body;
  final Widget footer;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 640),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PanelEyebrow(eyebrow),
        const SizedBox(height: PadloTokens.space12),
        Text(title, style: _WorldText.hero),
        const SizedBox(height: PadloTokens.space16),
        Text(body, style: _WorldText.bodyLarge),
        const SizedBox(height: PadloTokens.space24),
        DefaultTextStyle(style: _WorldText.caption, child: footer),
      ],
    ),
  );
}

final class _PanelEyebrow extends StatelessWidget {
  const _PanelEyebrow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(label, style: _WorldText.eyebrow);
}

abstract final class _WorldText {
  static const hero = TextStyle(
    color: Colors.white,
    fontSize: 52,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.6,
  );
  static const title = TextStyle(
    color: Colors.white,
    fontSize: 28,
    height: 1.08,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.7,
  );
  static const metric = TextStyle(
    color: Colors.white,
    fontSize: 34,
    fontWeight: FontWeight.w800,
  );
  static const bodyLarge = TextStyle(
    color: Color(0xFFE9ECFB),
    fontSize: 18,
    height: 1.5,
  );
  static const body = TextStyle(
    color: Color(0xFFD7DCEF),
    fontSize: 15,
    height: 1.45,
  );
  static const label = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );
  static const caption = TextStyle(
    color: Color(0xFFBBC3F3),
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );
  static const eyebrow = TextStyle(
    color: PadloTokens.accent,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.1,
  );
}

final class _MissionChoice extends StatelessWidget {
  const _MissionChoice({
    required this.label,
    required this.selected,
    required this.correct,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool correct;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        selected
            ? (correct ? Icons.check_rounded : Icons.close_rounded)
            : Icons.circle_outlined,
      ),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected
            ? correct
                  ? PadloTokens.success
                  : PadloTokens.accent
            : Colors.white,
        backgroundColor: selected ? Colors.white : Colors.transparent,
        side: BorderSide(
          color: selected
              ? correct
                    ? PadloTokens.success
                    : PadloTokens.accent
              : Colors.white38,
        ),
      ),
    ),
  );
}

final class _FeedbackLine extends StatelessWidget {
  const _FeedbackLine({required this.success, required this.text});

  final bool success;
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          success ? Icons.check_circle_rounded : Icons.info_rounded,
          color: success ? PadloTokens.success : PadloTokens.accent,
          size: 20,
        ),
        const SizedBox(width: PadloTokens.space8),
        Expanded(child: Text(text, style: _WorldText.caption)),
      ],
    ),
  );
}

final class _PortalTile extends StatelessWidget {
  const _PortalTile({
    required this.icon,
    required this.label,
    required this.status,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String status;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Open $label. $status',
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(PadloTokens.radiusSmall),
      focusColor: PadloTokens.tintStrong.withValues(alpha: 0.28),
      child: Ink(
        decoration: BoxDecoration(
          color: PadloTokens.primary.withValues(alpha: 0.34),
          border: Border.all(color: PadloTokens.primarySoft),
          borderRadius: BorderRadius.circular(PadloTokens.radiusSmall),
        ),
        padding: const EdgeInsets.all(PadloTokens.space12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: Colors.white),
            const SizedBox(height: PadloTokens.space8),
            Text(label, textAlign: TextAlign.center, style: _WorldText.label),
            const SizedBox(height: PadloTokens.space4),
            Text(
              status,
              textAlign: TextAlign.center,
              style: _WorldText.caption,
            ),
          ],
        ),
      ),
    ),
  );
}

final class _MatchToken extends StatelessWidget {
  const _MatchToken({
    required this.report,
    required this.selected,
    required this.onPressed,
  });

  final GameReport report;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '${report.city} match report, score ${report.score}',
    child: SizedBox(
      width: 230,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(PadloTokens.radiusLarge),
        child: Ink(
          padding: const EdgeInsets.all(PadloTokens.space20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? PadloTokens.primary.withValues(alpha: 0.88)
                : PadloTokens.darkSurface.withValues(alpha: 0.84),
            border: Border.all(
              color: selected ? PadloTokens.accent : PadloTokens.primarySoft,
              width: selected ? 3 : 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: PadloTokens.primary.withValues(alpha: 0.34),
                blurRadius: PadloTokens.space32,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('${report.score}', style: _WorldText.metric),
              Text(report.city, style: _WorldText.label),
              const SizedBox(height: PadloTokens.space4),
              Text(report.result, style: _WorldText.caption),
            ],
          ),
        ),
      ),
    ),
  );
}

final class _ScoreBeacon extends StatelessWidget {
  const _ScoreBeacon({required this.score, required this.change});

  final int score;
  final int change;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 112,
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: PadloTokens.primary.withValues(alpha: 0.7),
        border: Border.all(color: PadloTokens.accent, width: 3),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('$score', style: _WorldText.metric),
            Text('${change >= 0 ? '+' : ''}$change', style: _WorldText.caption),
          ],
        ),
      ),
    ),
  );
}

final class _TacticalCourt extends StatelessWidget {
  const _TacticalCourt({required this.report, required this.progress});

  final GameReport report;
  final double progress;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Animated tactical court heatmap',
    image: true,
    child: CustomPaint(
      painter: _CourtPainter(report.heatmap, progress),
      child: const SizedBox.expand(),
    ),
  );
}

final class _CourtPainter extends CustomPainter {
  const _CourtPainter(this.coordinates, this.progress);

  final List<CourtCoordinate> coordinates;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final court = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(PadloTokens.radiusSmall),
    );
    canvas.drawRRect(
      court,
      Paint()..color = PadloTokens.primary.withValues(alpha: 0.72),
    );
    final lines = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(court, lines);
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      lines,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      lines,
    );
    for (final coordinate in coordinates) {
      final center = Offset(
        coordinate.x * size.width,
        coordinate.y * size.height,
      );
      final radius = 10 + 15 * coordinate.intensity * (0.72 + progress * 0.28);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              PadloTokens.accent.withValues(alpha: coordinate.intensity),
              PadloTokens.accent.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CourtPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.coordinates != coordinates;
}

final class _WorldField extends StatelessWidget {
  const _WorldField({
    required this.controller,
    required this.label,
    required this.validator,
    this.keyboardType,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    validator: validator,
    keyboardType: keyboardType,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: PadloTokens.tintStrong),
      filled: true,
      fillColor: PadloTokens.darkSurfaceAlt.withValues(alpha: 0.92),
    ),
  );
}

final class _WorldDropdown<T extends Enum> extends StatelessWidget {
  const _WorldDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    initialValue: value,
    isExpanded: true,
    dropdownColor: PadloTokens.darkSurfaceAlt,
    style: const TextStyle(
      color: Colors.white,
      fontFamily: 'Epilogue',
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: PadloTokens.tintStrong),
      filled: true,
      fillColor: PadloTokens.darkSurfaceAlt.withValues(alpha: 0.92),
    ),
    items: values
        .map(
          (entry) => DropdownMenuItem<T>(
            value: entry,
            child: Text(enumLabel(entry), overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(growable: false),
    onChanged: (entry) {
      if (entry != null) onChanged(entry);
    },
  );
}

final class _ResetWorldDialog extends StatelessWidget {
  const _ResetWorldDialog();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reset the local Padlo world?'),
    content: const Text(
      'This removes the fictional player profile, tactical progress, and generated demo report from this device.',
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Keep progress'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        style: FilledButton.styleFrom(
          backgroundColor: PadloTokens.accentStrong,
        ),
        child: const Text('Reset local demo'),
      ),
    ],
  );
}

String? _validateName(String? value) {
  if ((value?.trim().length ?? 0) < 2) return 'Enter at least 2 characters.';
  return null;
}

String? _validateEmail(String? value) {
  final candidate = value?.trim() ?? '';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(candidate)) {
    return 'Enter a valid email address.';
  }
  return null;
}

String _durationLabel(Duration duration) =>
    '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
