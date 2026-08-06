import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../models/demo_models.dart';
import '../theme/padlo_theme.dart';
import '../widgets/padlo_primitives.dart';

final class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({required this.reportId, super.key});

  final String reportId;

  @override
  Widget build(BuildContext context) {
    final report = PadloScope.of(context).reportById(reportId);
    if (report == null) {
      return ProductPage(
        child: Center(
          child: PadloCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.search_off_rounded, size: 52),
                const SizedBox(height: PadloTokens.space16),
                Text(
                  'Report not found',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: PadloTokens.space16),
                PadloButton(
                  label: 'Back to reports',
                  onPressed: () => context.go('/app/reports'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return ProductPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextButton.icon(
            onPressed: () => context.go('/app/reports'),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('All reports'),
          ),
          const SizedBox(height: PadloTokens.space12),
          _ReportHero(report: report),
          const SizedBox(height: PadloTokens.space32),
          const SectionHeading(
            eyebrow: 'Positioning breakdown',
            title: 'Four signals. One clear priority.',
          ),
          const SizedBox(height: PadloTokens.space16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 980
                  ? 4
                  : constraints.maxWidth >= 560
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: PadloTokens.space16,
                runSpacing: PadloTokens.space16,
                children: report.metrics
                    .map(
                      (metric) => SizedBox(
                        width: width,
                        child: _MetricDetail(metric: metric),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
          const SizedBox(height: PadloTokens.space32),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 840;
              final heatmap = PadloCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Where the match lived',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: PadloTokens.space8),
                    Text(
                      'Coral zones show the positions that most influenced the report.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: PadloTokens.space20),
                    CourtHeatmap(points: report.heatmap),
                  ],
                ),
              );
              final moments = _MomentsCard(moments: report.moments);
              if (stacked) {
                return Column(
                  children: <Widget>[
                    heatmap,
                    const SizedBox(height: PadloTokens.space16),
                    moments,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 6, child: heatmap),
                  const SizedBox(width: PadloTokens.space16),
                  Expanded(flex: 5, child: moments),
                ],
              );
            },
          ),
          const SizedBox(height: PadloTokens.space32),
          _NextMatchPlanCard(plan: report.plan),
        ],
      ),
    );
  }
}

final class _ReportHero extends StatelessWidget {
  const _ReportHero({required this.report});

  final GameReport report;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: PadloTokens.primary,
      borderRadius: BorderRadius.circular(PadloTokens.radiusLarge),
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PadloTokens.radiusLarge),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Color(0xF22139C5),
            Color(0x9A243FD9),
            Color(0x52101835),
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600
              ? PadloTokens.space24
              : PadloTokens.space40,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 720;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(
                      PadloTokens.radiusSmall,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PadloTokens.space12,
                      vertical: PadloTokens.space8,
                    ),
                    child: Text(
                      '${report.city.toUpperCase()} · ${report.dateLabel.toUpperCase()} · ${report.timeLabel}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: PadloTokens.space24),
                Text(
                  'You protected the middle. Recovery is the next edge.',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.02,
                  ),
                ),
                const SizedBox(height: PadloTokens.space20),
                Text(
                  report.team,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                Text(
                  'vs ${report.opponents}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.padlo.tintStrong,
                  ),
                ),
                const SizedBox(height: PadloTokens.space8),
                Text(
                  report.result,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: PadloTokens.accent,
                  ),
                ),
              ],
            );
            final score = DecoratedBox(
              decoration: BoxDecoration(
                color: PadloTokens.darkSurface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(PadloTokens.radiusLarge),
              ),
              child: Padding(
                padding: const EdgeInsets.all(PadloTokens.space20),
                child: ScoreRing(score: report.score, size: narrow ? 128 : 160),
              ),
            );
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  copy,
                  const SizedBox(height: PadloTokens.space24),
                  score,
                ],
              );
            }
            return Row(
              children: <Widget>[
                Expanded(flex: 7, child: copy),
                const SizedBox(width: PadloTokens.space32),
                score,
              ],
            );
          },
        ),
      ),
    ),
  );
}

final class _MetricDetail extends StatelessWidget {
  const _MetricDetail({required this.metric});

  final PositioningMetric metric;

  @override
  Widget build(BuildContext context) => PadloCard(
    padding: const EdgeInsets.all(PadloTokens.space20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                metric.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              '${metric.score}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: PadloTokens.space12),
        LinearProgressIndicator(
          value: metric.score / 100,
          minHeight: PadloTokens.space8,
          borderRadius: BorderRadius.circular(PadloTokens.radiusSmall),
          backgroundColor: context.padlo.tint,
        ),
        const SizedBox(height: PadloTokens.space16),
        Text(
          metric.insight,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

final class _MomentsCard extends StatelessWidget {
  const _MomentsCard({required this.moments});

  final List<ReportMoment> moments;

  @override
  Widget build(BuildContext context) => PadloCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Tactical moments', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: PadloTokens.space8),
        Text(
          'The moments worth taking into your next session.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: PadloTokens.space16),
        for (final moment in moments) ...<Widget>[
          _MomentTile(moment: moment),
          if (moment != moments.last)
            const Divider(height: PadloTokens.space24),
        ],
      ],
    ),
  );
}

final class _MomentTile extends StatelessWidget {
  const _MomentTile({required this.moment});

  final ReportMoment moment;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      DecoratedBox(
        decoration: BoxDecoration(
          color: moment.severity > 0.5
              ? context.padlo.accent
              : context.padlo.tint,
          borderRadius: BorderRadius.circular(PadloTokens.radiusSmall),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PadloTokens.space8,
            vertical: PadloTokens.space4,
          ),
          child: Text(
            formatMoment(moment.time),
            style: TextStyle(
              color: moment.severity > 0.5 ? Colors.white : PadloTokens.ink,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      const SizedBox(width: PadloTokens.space12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(moment.title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: PadloTokens.space4),
            Text(
              moment.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

final class _NextMatchPlanCard extends StatelessWidget {
  const _NextMatchPlanCard({required this.plan});

  final NextMatchPlan plan;

  @override
  Widget build(BuildContext context) => PadloCard(
    color: context.padlo.tint,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'NEXT MATCH PLAN',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: PadloTokens.space12),
        Text(plan.correction, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: PadloTokens.space24),
        Wrap(
          spacing: PadloTokens.space24,
          runSpacing: PadloTokens.space20,
          children: <Widget>[
            _PlanItem(
              icon: Icons.fitness_center,
              label: 'Drill',
              value: plan.drill,
            ),
            _PlanItem(
              icon: Icons.record_voice_over_outlined,
              label: 'Court cue',
              value: plan.cue,
            ),
          ],
        ),
      ],
    ),
  );
}

final class _PlanItem extends StatelessWidget {
  const _PlanItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 440,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: PadloTokens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: PadloTokens.space4),
              Text(value),
            ],
          ),
        ),
      ],
    ),
  );
}
