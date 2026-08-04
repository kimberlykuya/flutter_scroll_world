import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/demo_models.dart';
import '../theme/padlo_theme.dart';

final class PadloLogo extends StatelessWidget {
  const PadloLogo({this.light = false, this.height = 30, super.key});

  final bool light;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Padlo',
    child: ColorFiltered(
      colorFilter: light
          ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
          : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
      child: Image.asset(
        'assets/brand/padlo-logo.png',
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Text(
          'padlo',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: light ? Colors.white : PadloTokens.ink,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
          ),
        ),
      ),
    ),
  );
}

enum PadloButtonVariant { primary, secondary, tonal }

final class PadloButton extends StatelessWidget {
  const PadloButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = PadloButtonVariant.primary,
    this.loading = false,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final PadloButtonVariant variant;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = !loading && onPressed != null;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (loading)
          const SizedBox.square(
            dimension: PadloTokens.space20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (icon != null)
          Icon(icon, size: PadloTokens.space20),
        if (loading || icon != null) const SizedBox(width: PadloTokens.space8),
        Text(label),
      ],
    );
    final callback = enabled ? onPressed : null;
    final button = switch (variant) {
      PadloButtonVariant.primary => FilledButton(
        onPressed: callback,
        child: content,
      ),
      PadloButtonVariant.secondary => OutlinedButton(
        onPressed: callback,
        child: content,
      ),
      PadloButtonVariant.tonal => FilledButton.tonal(
        onPressed: callback,
        child: content,
      ),
    };
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      liveRegion: loading,
      value: loading ? 'Loading' : null,
      child: button,
    );
  }
}

final class PadloCard extends StatelessWidget {
  const PadloCard({
    required this.child,
    this.padding = const EdgeInsets.all(PadloTokens.space24),
    this.color,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: Card(
        color: color,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                focusColor: Theme.of(context).focusColor,
                child: content,
              ),
      ),
    );
  }
}

final class ProofOfConceptBadge extends StatelessWidget {
  const ProofOfConceptBadge({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Proof of concept. All data is simulated.',
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.padlo.tint,
        borderRadius: BorderRadius.circular(PadloTokens.radiusSmall),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: PadloTokens.space12,
          vertical: PadloTokens.space8,
        ),
        child: IconTheme(
          data: IconThemeData(color: PadloTokens.ink),
          child: DefaultTextStyle(
            style: TextStyle(color: PadloTokens.ink),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.science_outlined, size: PadloTokens.space16),
                SizedBox(width: PadloTokens.space8),
                Flexible(
                  child: Text(
                    'PROOF OF CONCEPT · SIMULATED DATA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

final class SectionHeading extends StatelessWidget {
  const SectionHeading({
    required this.eyebrow,
    required this.title,
    this.description,
    this.trailing,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              eyebrow.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: PadloTokens.space8),
            Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            if (description != null) ...<Widget>[
              const SizedBox(height: PadloTokens.space8),
              Text(
                description!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      if (trailing != null) ...<Widget>[
        const SizedBox(width: PadloTokens.space16),
        trailing!,
      ],
    ],
  );
}

final class ScoreRing extends StatelessWidget {
  const ScoreRing({required this.score, this.size = 150, super.key});

  final int score;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Positioning score $score out of 100',
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _ScoreRingPainter(
          progress: score / 100,
          active: Theme.of(context).colorScheme.primary,
          inactive: context.padlo.tint,
        ),
        child: Center(
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: 1,
            maxScaleFactor: 1.2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '$score',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text('OF 100', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

final class _ScoreRingPainter extends CustomPainter {
  const _ScoreRingPainter({
    required this.progress,
    required this.active,
    required this.inactive,
  });

  final double progress;
  final Color active;
  final Color inactive;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final basePaint = Paint()
      ..color = inactive
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final activePaint = Paint()
      ..color = active
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, -math.pi * 0.75, math.pi * 1.5, false, basePaint);
    canvas.drawArc(
      arcRect,
      -math.pi * 0.75,
      math.pi * 1.5 * progress,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.active != active ||
      oldDelegate.inactive != inactive;
}

final class CourtHeatmap extends StatelessWidget {
  const CourtHeatmap({
    required this.points,
    this.showPlayers = true,
    super.key,
  });

  final List<CourtCoordinate> points;
  final bool showPlayers;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Padel court positioning heatmap',
    child: AspectRatio(
      aspectRatio: 1.48,
      child: CustomPaint(
        painter: _CourtPainter(
          points: points,
          primary: Theme.of(context).colorScheme.primary,
          accent: context.padlo.accent,
          line: Theme.of(context).colorScheme.onPrimary,
          showPlayers: showPlayers,
        ),
      ),
    ),
  );
}

final class _CourtPainter extends CustomPainter {
  const _CourtPainter({
    required this.points,
    required this.primary,
    required this.accent,
    required this.line,
    required this.showPlayers,
  });

  final List<CourtCoordinate> points;
  final Color primary;
  final Color accent;
  final Color line;
  final bool showPlayers;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final radius = Radius.circular(size.shortestSide * 0.045);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, radius),
      Paint()..color = primary,
    );
    for (final point in points) {
      final center = Offset(point.x * size.width, point.y * size.height);
      final heat = Paint()
        ..shader =
            RadialGradient(
              colors: <Color>[
                accent.withValues(alpha: 0.75 * point.intensity),
                accent.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: center, radius: size.width * 0.17),
            );
      canvas.drawCircle(center, size.width * 0.17, heat);
    }
    final linePaint = Paint()
      ..color = line.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, size.width * 0.004);
    final inset = size.width * 0.055;
    final court = Rect.fromLTRB(
      inset,
      inset,
      size.width - inset,
      size.height - inset,
    );
    canvas.drawRect(court, linePaint);
    canvas.drawLine(
      Offset(inset, size.height / 2),
      Offset(size.width - inset, size.height / 2),
      linePaint..strokeWidth *= 1.8,
    );
    canvas.drawLine(
      Offset(inset, size.height * 0.25),
      Offset(size.width - inset, size.height * 0.25),
      linePaint..strokeWidth /= 1.8,
    );
    canvas.drawLine(
      Offset(inset, size.height * 0.75),
      Offset(size.width - inset, size.height * 0.75),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width / 2, inset),
      Offset(size.width / 2, size.height * 0.25),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.75),
      Offset(size.width / 2, size.height - inset),
      linePaint,
    );
    if (showPlayers) {
      final playerPaint = Paint()..color = line;
      for (final offset in <Offset>[
        Offset(size.width * 0.34, size.height * 0.36),
        Offset(size.width * 0.66, size.height * 0.38),
        Offset(size.width * 0.37, size.height * 0.68),
        Offset(size.width * 0.63, size.height * 0.65),
      ]) {
        canvas.drawCircle(offset, size.width * 0.018, playerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CourtPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.primary != primary ||
      oldDelegate.accent != accent ||
      oldDelegate.line != line ||
      oldDelegate.showPlayers != showPlayers;
}

String formatMoment(Duration duration) =>
    '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

final class ProductPage extends StatelessWidget {
  const ProductPage({required this.child, this.maxWidth = 1240, super.key});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width < 600
            ? PadloTokens.space16
            : PadloTokens.space32,
        vertical: PadloTokens.space32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    ),
  );
}
