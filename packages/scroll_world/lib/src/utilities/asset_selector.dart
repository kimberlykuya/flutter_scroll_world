import '../models/scroll_world_source.dart';

final class ScrollWorldEnvironment {
  const ScrollWorldEnvironment({
    required this.isWeb,
    required this.isPortrait,
    required this.viewportWidth,
    required this.devicePixelRatio,
  });

  final bool isWeb;
  final bool isPortrait;
  final double viewportWidth;
  final double devicePixelRatio;
}

ScrollWorldSource selectScrollWorldSource(
  ScrollWorldSources sources,
  ScrollWorldEnvironment environment, {
  required double mobileBreakpoint,
  required double webHighPhysicalWidth,
}) {
  if (sources.isEmpty) {
    throw ArgumentError.value(sources, 'sources', 'must not be empty');
  }
  if (environment.isPortrait && sources.mobilePortrait != null) {
    return sources.mobilePortrait!;
  }
  if (environment.viewportWidth < mobileBreakpoint &&
      sources.mobileLandscape != null) {
    return sources.mobileLandscape!;
  }
  if (environment.isWeb &&
      environment.viewportWidth * environment.devicePixelRatio >=
          webHighPhysicalWidth &&
      sources.webHigh != null) {
    return sources.webHigh!;
  }
  return sources.webStandard ??
      sources.mobileLandscape ??
      sources.mobilePortrait ??
      sources.webHigh!;
}
