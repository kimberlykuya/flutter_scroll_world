import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../models/demo_models.dart';
import '../theme/padlo_theme.dart';
import '../widgets/padlo_primitives.dart';

enum _AnalysisStage { ready, preparing, readingCourt, buildingReport, complete }

final class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

final class _RecordScreenState extends State<RecordScreen> {
  _AnalysisStage _stage = _AnalysisStage.ready;
  int _generation = 0;

  bool get _running =>
      _stage != _AnalysisStage.ready && _stage != _AnalysisStage.complete;

  Future<void> _analyze() async {
    if (_running) return;
    final generation = ++_generation;
    for (final stage in <_AnalysisStage>[
      _AnalysisStage.preparing,
      _AnalysisStage.readingCourt,
      _AnalysisStage.buildingReport,
    ]) {
      if (!mounted || generation != _generation) return;
      setState(() => _stage = stage);
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    if (!mounted || generation != _generation) return;
    await PadloScope.of(context).markReportGenerated();
    if (mounted) setState(() => _stage = _AnalysisStage.complete);
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProductPage(
    maxWidth: 1120,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeading(
          eyebrow: 'Demo analysis',
          title: 'Turn one match into your next move',
          description:
              'This simulation demonstrates the product flow. No video is selected, uploaded, or transmitted.',
        ),
        const SizedBox(height: PadloTokens.space32),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 820;
            final visual = _AnalysisVisual(stage: _stage);
            final panel = _AnalysisPanel(
              stage: _stage,
              onAnalyze: _analyze,
              onViewReport: () =>
                  context.go('/app/reports/${featuredReport.id}'),
              onReset: () => setState(() => _stage = _AnalysisStage.ready),
            );
            if (stacked) {
              return Column(
                children: <Widget>[
                  visual,
                  const SizedBox(height: PadloTokens.space16),
                  panel,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 7, child: visual),
                const SizedBox(width: PadloTokens.space20),
                Expanded(flex: 5, child: panel),
              ],
            );
          },
        ),
        const SizedBox(height: PadloTokens.space32),
        Wrap(
          spacing: PadloTokens.space16,
          runSpacing: PadloTokens.space16,
          children: const <Widget>[
            _TrustPoint(
              icon: Icons.lock_outline,
              title: 'Local simulation',
              text: 'No media leaves this device.',
            ),
            _TrustPoint(
              icon: Icons.route_outlined,
              title: 'Court coordinates',
              text: 'Movement becomes tactical evidence.',
            ),
            _TrustPoint(
              icon: Icons.fact_check_outlined,
              title: 'Actionable report',
              text: 'One correction for the next match.',
            ),
          ],
        ),
      ],
    ),
  );
}

final class _AnalysisVisual extends StatelessWidget {
  const _AnalysisVisual({required this.stage});

  final _AnalysisStage stage;

  @override
  Widget build(BuildContext context) {
    final progress = switch (stage) {
      _AnalysisStage.ready => 0.0,
      _AnalysisStage.preparing => 0.18,
      _AnalysisStage.readingCourt => 0.52,
      _AnalysisStage.buildingReport => 0.82,
      _AnalysisStage.complete => 1.0,
    };
    return PadloCard(
      color: PadloTokens.darkSurface,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PadloTokens.radiusMedium),
        child: Stack(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(PadloTokens.space24),
              child: CourtHeatmap(
                points: <CourtCoordinate>[],
                showPlayers: true,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: PadloTokens.motionStandard,
                  opacity: stage == _AnalysisStage.ready ? 0 : 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.transparent,
                          PadloTokens.darkSurface.withValues(alpha: 0.82),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: PadloTokens.space24,
              right: PadloTokens.space24,
              bottom: PadloTokens.space24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    stage == _AnalysisStage.complete
                        ? 'REPORT READY'
                        : stage == _AnalysisStage.ready
                        ? 'LJUBLJANA · DEMO MATCH'
                        : 'READING PLAYER POSITIONS',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: PadloTokens.space12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      PadloTokens.radiusSmall,
                    ),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: PadloTokens.space8,
                      backgroundColor: Colors.white24,
                      color: PadloTokens.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _AnalysisPanel extends StatelessWidget {
  const _AnalysisPanel({
    required this.stage,
    required this.onAnalyze,
    required this.onViewReport,
    required this.onReset,
  });

  final _AnalysisStage stage;
  final VoidCallback onAnalyze;
  final VoidCallback onViewReport;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final title = switch (stage) {
      _AnalysisStage.ready => 'A prepared match is waiting',
      _AnalysisStage.preparing => 'Preparing the court model',
      _AnalysisStage.readingCourt => 'Measuring player movement',
      _AnalysisStage.buildingReport => 'Building tactical guidance',
      _AnalysisStage.complete => 'Your Ljubljana report is ready',
    };
    final description = switch (stage) {
      _AnalysisStage.ready =>
        'Use the fictional Luka Novak match to see how Padlo turns movement into positioning guidance.',
      _AnalysisStage.preparing =>
        'Calibrating the court boundaries and aligning the simulated match.',
      _AnalysisStage.readingCourt =>
        'Tracking net depth, recovery timing, partner spacing, and transition decisions.',
      _AnalysisStage.buildingReport =>
        'Selecting the most useful correction and creating your next-match plan.',
      _AnalysisStage.complete =>
        'Score 72. Partner spacing is strong; recovery timing is the next opportunity.',
    };
    final running =
        stage != _AnalysisStage.ready && stage != _AnalysisStage.complete;
    return Semantics(
      liveRegion: running,
      child: PadloCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              radius: 28,
              backgroundColor: stage == _AnalysisStage.complete
                  ? context.padlo.success.withValues(alpha: 0.15)
                  : context.padlo.tint,
              foregroundColor: stage == _AnalysisStage.complete
                  ? context.padlo.success
                  : Theme.of(context).colorScheme.primary,
              child: Icon(
                stage == _AnalysisStage.complete
                    ? Icons.check_rounded
                    : Icons.auto_graph_rounded,
              ),
            ),
            const SizedBox(height: PadloTokens.space24),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: PadloTokens.space12),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: PadloTokens.space24),
            if (stage == _AnalysisStage.complete) ...<Widget>[
              PadloButton(
                label: 'Open positioning report',
                icon: Icons.arrow_forward_rounded,
                expand: true,
                onPressed: onViewReport,
              ),
              const SizedBox(height: PadloTokens.space12),
              PadloButton(
                label: 'Run simulation again',
                variant: PadloButtonVariant.secondary,
                expand: true,
                onPressed: onReset,
              ),
            ] else
              PadloButton(
                key: const Key('analyze-demo-match'),
                label: running ? 'Analyzing demo match' : 'Analyze demo match',
                icon: Icons.play_arrow_rounded,
                loading: running,
                expand: true,
                onPressed: running ? null : onAnalyze,
              ),
          ],
        ),
      ),
    );
  }
}

final class _TrustPoint extends StatelessWidget {
  const _TrustPoint({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 260,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: PadloTokens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
