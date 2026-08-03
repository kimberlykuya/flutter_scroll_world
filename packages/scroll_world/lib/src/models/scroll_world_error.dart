import 'scroll_world_source.dart';

/// A playback failure reported while poster rendering continues.
final class ScrollWorldPlaybackError {
  const ScrollWorldPlaybackError({
    required this.mediaKey,
    required this.source,
    required this.error,
    required this.stackTrace,
    required this.attempt,
  });

  final String mediaKey;
  final ScrollWorldSource source;
  final Object error;
  final StackTrace stackTrace;
  final int attempt;

  @override
  String toString() =>
      'ScrollWorldPlaybackError($mediaKey, attempt: $attempt, error: $error)';
}

typedef ScrollWorldErrorCallback =
    void Function(ScrollWorldPlaybackError error);
