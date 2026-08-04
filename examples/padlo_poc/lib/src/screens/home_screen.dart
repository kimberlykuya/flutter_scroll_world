import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../models/demo_models.dart';
import '../theme/padlo_theme.dart';
import '../widgets/padlo_primitives.dart';

final class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = PadloScope.of(context);
    final firstName = store.profile?.firstName ?? 'Luka';
    return ProductPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeading(
            eyebrow: 'Your positioning room',
            title: 'Dobrodošel, $firstName.',
            description:
                'Your last three Slovenian matches reveal one clear opportunity: recover earlier after the overhead.',
            trailing: MediaQuery.sizeOf(context).width >= 760
                ? PadloButton(
                    label: 'Analyze a demo match',
                    icon: Icons.videocam_outlined,
                    onPressed: () => context.go('/app/record'),
                  )
                : null,
          ),
          if (MediaQuery.sizeOf(context).width < 760) ...<Widget>[
            const SizedBox(height: PadloTokens.space20),
            PadloButton(
              label: 'Analyze a demo match',
              icon: Icons.videocam_outlined,
              expand: true,
              onPressed: () => context.go('/app/record'),
            ),
          ],
          const SizedBox(height: PadloTokens.space32),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 760;
              final score = PadloCard(
                child: Row(
                  children: <Widget>[
                    const ScoreRing(score: 72, size: 132),
                    const SizedBox(width: PadloTokens.space24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Latest positioning score',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: PadloTokens.space8),
                          Text(
                            '+6 since Maribor',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: context.padlo.success),
                          ),
                          const SizedBox(height: PadloTokens.space8),
                          Text(
                            'Strong partner spacing lifted your overall result.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
              final priority = _PriorityCard(
                onOpen: () => context.go('/app/reports/${featuredReport.id}'),
              );
              if (narrow) {
                return Column(
                  children: <Widget>[
                    score,
                    const SizedBox(height: PadloTokens.space16),
                    priority,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 6, child: score),
                  const SizedBox(width: PadloTokens.space16),
                  Expanded(flex: 5, child: priority),
                ],
              );
            },
          ),
          const SizedBox(height: PadloTokens.space32),
          Text(
            'Positioning breakdown',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: PadloTokens.space16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1000
                  ? 4
                  : constraints.maxWidth >= 560
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: PadloTokens.space16,
                runSpacing: PadloTokens.space16,
                children: featuredReport.metrics
                    .map(
                      (metric) => SizedBox(
                        width: width,
                        child: _MetricSummary(metric: metric),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
          const SizedBox(height: PadloTokens.space40),
          SectionHeading(
            eyebrow: 'Recent form',
            title: 'Your Slovenian match trail',
            trailing: TextButton(
              onPressed: () => context.go('/app/reports'),
              child: const Text('View all reports'),
            ),
          ),
          const SizedBox(height: PadloTokens.space16),
          ...demoReports.map(
            (report) => Padding(
              padding: const EdgeInsets.only(bottom: PadloTokens.space12),
              child: _RecentMatchTile(report: report),
            ),
          ),
        ],
      ),
    );
  }
}

final class _PriorityCard extends StatelessWidget {
  const _PriorityCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => PadloCard(
    color: Theme.of(context).colorScheme.primary,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.bolt_rounded, color: PadloTokens.accent, size: 32),
        const SizedBox(height: PadloTokens.space24),
        Text(
          'Priority correction',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: context.padlo.tintStrong),
        ),
        const SizedBox(height: PadloTokens.space8),
        Text(
          'Recover before looking for the next attack.',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: PadloTokens.space20),
        FilledButton.tonalIcon(
          onPressed: onOpen,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('See the tactical moment'),
        ),
      ],
    ),
  );
}

final class _MetricSummary extends StatelessWidget {
  const _MetricSummary({required this.metric});

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
        const SizedBox(height: PadloTokens.space16),
        ClipRRect(
          borderRadius: BorderRadius.circular(PadloTokens.radiusSmall),
          child: LinearProgressIndicator(
            value: metric.score / 100,
            minHeight: PadloTokens.space8,
            backgroundColor: context.padlo.tint,
          ),
        ),
        const SizedBox(height: PadloTokens.space12),
        Text(
          '${metric.change >= 0 ? '+' : ''}${metric.change} vs previous match',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: metric.change >= 0
                ? context.padlo.success
                : context.padlo.accentStrong,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

final class _RecentMatchTile extends StatelessWidget {
  const _RecentMatchTile({required this.report});

  final GameReport report;

  @override
  Widget build(BuildContext context) => PadloCard(
    onTap: () => context.go('/app/reports/${report.id}'),
    semanticLabel: 'Open ${report.city} match report',
    padding: const EdgeInsets.symmetric(
      horizontal: PadloTokens.space20,
      vertical: PadloTokens.space16,
    ),
    child: Row(
      children: <Widget>[
        CircleAvatar(
          backgroundColor: context.padlo.tint,
          foregroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.sports_tennis_rounded),
        ),
        const SizedBox(width: PadloTokens.space16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(report.city, style: Theme.of(context).textTheme.titleMedium),
              Text(
                '${report.dateLabel} · ${report.result}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              '${report.score}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Text(
              '${report.change >= 0 ? '+' : ''}${report.change}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: report.change >= 0
                    ? context.padlo.success
                    : context.padlo.accentStrong,
              ),
            ),
          ],
        ),
        const SizedBox(width: PadloTokens.space8),
        const Icon(Icons.chevron_right_rounded),
      ],
    ),
  );
}
