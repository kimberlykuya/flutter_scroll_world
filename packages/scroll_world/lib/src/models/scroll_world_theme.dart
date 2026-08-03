import 'package:flutter/material.dart';

/// Styling for the built-in Scroll World presentation.
@immutable
final class ScrollWorldTheme {
  const ScrollWorldTheme({
    this.backgroundColor = const Color(0xFF07130F),
    this.overlayGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0x00000000), Color(0x1A000000), Color(0xD9000000)],
      stops: <double>[0, 0.45, 1],
    ),
    this.titleStyle,
    this.descriptionStyle,
    this.progressActiveColor = const Color(0xFFF2B134),
    this.progressInactiveColor = const Color(0x66FFFFFF),
    this.overlayPadding = const EdgeInsets.fromLTRB(28, 28, 28, 72),
    this.overlayMaxWidth = 620,
    this.actionSpacing = 28,
  });

  final Color backgroundColor;
  final Gradient overlayGradient;
  final TextStyle? titleStyle;
  final TextStyle? descriptionStyle;
  final Color progressActiveColor;
  final Color progressInactiveColor;
  final EdgeInsets overlayPadding;
  final double overlayMaxWidth;
  final double actionSpacing;
}
