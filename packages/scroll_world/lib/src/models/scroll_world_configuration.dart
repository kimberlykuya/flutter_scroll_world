import 'package:flutter/widgets.dart';

enum ScrollWorldWebMediaStrategy { blob, direct }

/// Advanced playback and presentation settings.
@immutable
final class ScrollWorldConfiguration {
  const ScrollWorldConfiguration({
    this.preloadRadius = 1,
    this.seekTolerance = const Duration(milliseconds: 8),
    this.mobileSeekTolerance = const Duration(milliseconds: 20),
    this.maximumSeekFrequency = const Duration(milliseconds: 16),
    this.smoothingFactor = 0.18,
    this.transitionCurve = Curves.easeInOut,
    this.seamFadeFraction = 0.12,
    this.fit = BoxFit.cover,
    this.initializationRetryCount = 1,
    this.showProgressNavigation = true,
    this.respectReducedMotion = true,
    this.mobileBreakpoint = 900,
    this.webHighPhysicalWidth = 1920,
    this.webMediaStrategy = ScrollWorldWebMediaStrategy.blob,
    this.navigationDuration = const Duration(milliseconds: 700),
    this.reverseReplayDuration = const Duration(seconds: 10),
  });

  final int preloadRadius;
  final Duration seekTolerance;
  final Duration mobileSeekTolerance;
  final Duration maximumSeekFrequency;
  final double smoothingFactor;
  final Curve transitionCurve;
  final double seamFadeFraction;
  final BoxFit fit;
  final int initializationRetryCount;
  final bool showProgressNavigation;
  final bool respectReducedMotion;
  final double mobileBreakpoint;
  final double webHighPhysicalWidth;
  final ScrollWorldWebMediaStrategy webMediaStrategy;
  final Duration navigationDuration;
  final Duration reverseReplayDuration;

  void validate() {
    if (preloadRadius < 0) {
      throw ArgumentError.value(preloadRadius, 'preloadRadius', 'must be >= 0');
    }
    if (seekTolerance.isNegative ||
        mobileSeekTolerance.isNegative ||
        maximumSeekFrequency.isNegative) {
      throw ArgumentError('seek durations must be non-negative');
    }
    if (!smoothingFactor.isFinite ||
        smoothingFactor <= 0 ||
        smoothingFactor > 1) {
      throw ArgumentError.value(
        smoothingFactor,
        'smoothingFactor',
        'must be greater than zero and at most one',
      );
    }
    if (seamFadeFraction <= 0 || seamFadeFraction >= 0.5) {
      throw ArgumentError.value(
        seamFadeFraction,
        'seamFadeFraction',
        'must be greater than 0 and less than 0.5',
      );
    }
    if (initializationRetryCount < 0) {
      throw ArgumentError.value(
        initializationRetryCount,
        'initializationRetryCount',
        'must be >= 0',
      );
    }
    if (mobileBreakpoint <= 0 || webHighPhysicalWidth <= 0) {
      throw ArgumentError('source breakpoints must be positive');
    }
    if (navigationDuration.isNegative || reverseReplayDuration.isNegative) {
      throw ArgumentError('navigation durations must be non-negative');
    }
  }
}
