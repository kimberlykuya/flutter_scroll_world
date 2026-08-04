import 'package:flutter/material.dart';

abstract final class PadloTokens {
  static const Color primary = Color(0xFF243FD9);
  static const Color primaryStrong = Color(0xFF2139C5);
  static const Color primarySoft = Color(0xFF466AED);
  static const Color accent = Color(0xFFEE8B60);
  static const Color accentStrong = Color(0xFFDA3917);
  static const Color ink = Color(0xFF14181B);
  static const Color muted = Color(0xFF6A6A6A);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF2F2F2);
  static const Color tint = Color(0xFFE9ECFB);
  static const Color tintStrong = Color(0xFFBBC3F3);
  static const Color success = Color(0xFF16856B);
  static const Color warning = Color(0xFFE7A227);
  static const Color darkSurface = Color(0xFF10131D);
  static const Color darkSurfaceAlt = Color(0xFF181D2A);

  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space40 = 40;
  static const double space48 = 48;
  static const double space64 = 64;
  static const double radiusSmall = 10;
  static const double radiusMedium = 18;
  static const double radiusLarge = 28;
  static const double controlHeight = 48;
  static const Duration motionFast = Duration(milliseconds: 160);
  static const Duration motionStandard = Duration(milliseconds: 320);
}

@immutable
final class PadloPalette extends ThemeExtension<PadloPalette> {
  const PadloPalette({
    required this.accent,
    required this.accentStrong,
    required this.tint,
    required this.tintStrong,
    required this.success,
    required this.warning,
  });

  final Color accent;
  final Color accentStrong;
  final Color tint;
  final Color tintStrong;
  final Color success;
  final Color warning;

  @override
  PadloPalette copyWith({
    Color? accent,
    Color? accentStrong,
    Color? tint,
    Color? tintStrong,
    Color? success,
    Color? warning,
  }) => PadloPalette(
    accent: accent ?? this.accent,
    accentStrong: accentStrong ?? this.accentStrong,
    tint: tint ?? this.tint,
    tintStrong: tintStrong ?? this.tintStrong,
    success: success ?? this.success,
    warning: warning ?? this.warning,
  );

  @override
  PadloPalette lerp(covariant PadloPalette? other, double t) {
    if (other == null) return this;
    return PadloPalette(
      accent: Color.lerp(accent, other.accent, t)!,
      accentStrong: Color.lerp(accentStrong, other.accentStrong, t)!,
      tint: Color.lerp(tint, other.tint, t)!,
      tintStrong: Color.lerp(tintStrong, other.tintStrong, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

ThemeData buildPadloTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: PadloTokens.primary,
    brightness: brightness,
    primary: dark ? PadloTokens.primarySoft : PadloTokens.primary,
    surface: dark ? PadloTokens.darkSurface : PadloTokens.surface,
    error: PadloTokens.accentStrong,
  );
  final textTheme = ThemeData(brightness: brightness).textTheme.apply(
    fontFamily: 'Epilogue',
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Epilogue',
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? PadloTokens.darkSurface
        : PadloTokens.surfaceAlt,
    textTheme: textTheme.copyWith(
      displayLarge: textTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -2.2,
        height: 0.98,
      ),
      displayMedium: textTheme.displayMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
        height: 1,
      ),
      headlineLarge: textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: textTheme.bodyLarge?.copyWith(height: 1.55),
      bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.5),
      labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    extensions: const <ThemeExtension<dynamic>>[
      PadloPalette(
        accent: PadloTokens.accent,
        accentStrong: PadloTokens.accentStrong,
        tint: PadloTokens.tint,
        tintStrong: PadloTokens.tintStrong,
        success: PadloTokens.success,
        warning: PadloTokens.warning,
      ),
    ],
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? PadloTokens.darkSurfaceAlt : PadloTokens.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PadloTokens.radiusMedium),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, PadloTokens.controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: PadloTokens.space24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PadloTokens.radiusSmall),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, PadloTokens.controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: PadloTokens.space24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PadloTokens.radiusSmall),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? PadloTokens.darkSurfaceAlt : PadloTokens.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: PadloTokens.space16,
        vertical: PadloTokens.space16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PadloTokens.radiusSmall),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PadloTokens.radiusSmall),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PadloTokens.radiusSmall),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    focusColor: PadloTokens.tintStrong.withValues(alpha: 0.35),
  );
}

extension PadloThemeContext on BuildContext {
  PadloPalette get padlo => Theme.of(this).extension<PadloPalette>()!;
}
