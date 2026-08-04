import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../models/demo_models.dart';
import '../theme/padlo_theme.dart';
import '../widgets/padlo_primitives.dart';

final class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

final class _ReportsScreenState extends State<ReportsScreen> {
  String _city = 'All cities';

  @override
  Widget build(BuildContext context) {
    final store = PadloScope.of(context);
    final reports = store.reports
        .where((report) => _city == 'All cities' || report.city == _city)
        .toList(growable: false);
    return ProductPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeading(
            eyebrow: 'Match archive',
            title: 'Every match leaves a pattern',
            description:
                'Compare positioning scores across Ljubljana, Maribor, and Koper.',
          ),
          const SizedBox(height: PadloTokens.space24),
          Wrap(
            spacing: PadloTokens.space8,
            runSpacing: PadloTokens.space8,
            children: <String>['All cities', 'Ljubljana', 'Maribor', 'Koper']
                .map(
                  (city) => ChoiceChip(
                    label: Text(city),
                    selected: _city == city,
                    onSelected: (selected) {
                      if (selected) setState(() => _city = city);
                    },
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: PadloTokens.space32),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1000
                  ? 3
                  : constraints.maxWidth >= 650
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: PadloTokens.space16,
                runSpacing: PadloTokens.space16,
                children: reports
                    .map(
                      (report) => SizedBox(
                        width: width,
                        child: _ReportCard(report: report),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
          const SizedBox(height: PadloTokens.space40),
          const _TrendCard(),
        ],
      ),
    );
  }
}

final class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final GameReport report;

  @override
  Widget build(BuildContext context) => PadloCard(
    onTap: () => context.go('/app/reports/${report.id}'),
    semanticLabel: 'Open ${report.city} positioning report',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: context.padlo.tint,
                borderRadius: BorderRadius.circular(PadloTokens.radiusSmall),
              ),
              child: const Padding(
                padding: EdgeInsets.all(PadloTokens.space12),
                child: Icon(Icons.location_on_outlined),
              ),
            ),
            const Spacer(),
            Text(
              '${report.change >= 0 ? '+' : ''}${report.change}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: report.change >= 0
                    ? context.padlo.success
                    : context.padlo.accentStrong,
              ),
            ),
          ],
        ),
        const SizedBox(height: PadloTokens.space24),
        Text(report.city, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: PadloTokens.space4),
        Text(
          '${report.dateLabel} · ${report.timeLabel}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: PadloTokens.space16),
        Text(report.result, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: PadloTokens.space20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              '${report.score}',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(
                left: PadloTokens.space8,
                bottom: PadloTokens.space8,
              ),
              child: Text('POSITIONING'),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_rounded),
          ],
        ),
      ],
    ),
  );
}

final class _TrendCard extends StatelessWidget {
  const _TrendCard();

  @override
  Widget build(BuildContext context) => PadloCard(
    color: Theme.of(context).colorScheme.primary,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 660;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'THREE-MATCH TREND',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.padlo.tintStrong,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: PadloTokens.space12),
            Text(
              'Your positioning score is moving in the right direction.',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: PadloTokens.space8),
            Text(
              '62  →  66  →  72',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: PadloTokens.accent),
            ),
          ],
        );
        final insight = DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(PadloTokens.radiusMedium),
          ),
          child: const Padding(
            padding: EdgeInsets.all(PadloTokens.space20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.trending_up_rounded, color: PadloTokens.accent),
                SizedBox(width: PadloTokens.space12),
                Flexible(
                  child: Text(
                    '+10 points across Koper, Maribor, and Ljubljana',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              copy,
              const SizedBox(height: PadloTokens.space24),
              insight,
            ],
          );
        }
        return Row(
          children: <Widget>[
            Expanded(child: copy),
            const SizedBox(width: PadloTokens.space24),
            Expanded(child: insight),
          ],
        );
      },
    ),
  );
}
