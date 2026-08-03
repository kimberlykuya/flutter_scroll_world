import 'dart:async';

/// Coalesces rapid seeks and always finishes at the latest requested target.
final class SeekScheduler {
  SeekScheduler({required this.tolerance, required this.maximumFrequency});

  final Duration tolerance;
  final Duration maximumFrequency;

  Duration? _latestTarget;
  Duration? _lastCompletedTarget;
  Completer<void>? _drainCompleter;
  DateTime? _lastSeekAt;
  Timer? _waitTimer;
  Completer<void>? _waitCompleter;
  int _generation = 0;
  bool _disposed = false;

  bool get isSeeking => _drainCompleter != null;

  Future<void> request(
    Duration target,
    Future<void> Function(Duration target) performSeek,
  ) {
    if (_disposed) return Future<void>.value();
    if (_lastCompletedTarget case final completed?
        when (completed - target).abs() <= tolerance) {
      return Future<void>.value();
    }
    _latestTarget = target;
    if (_drainCompleter case final active?) return active.future;

    final completer = Completer<void>();
    _drainCompleter = completer;
    final generation = _generation;
    unawaited(_drain(generation, performSeek, completer));
    return completer.future;
  }

  void invalidate() {
    _generation++;
    _latestTarget = null;
    _lastCompletedTarget = null;
  }

  void dispose() {
    _disposed = true;
    _waitTimer?.cancel();
    if (_waitCompleter case final completer? when !completer.isCompleted) {
      completer.complete();
    }
    invalidate();
  }

  Future<void> _drain(
    int generation,
    Future<void> Function(Duration target) performSeek,
    Completer<void> completer,
  ) async {
    try {
      while (!_disposed && generation == _generation) {
        final target = _latestTarget;
        if (target == null) break;
        _latestTarget = null;

        if (_lastSeekAt case final last?) {
          final remaining = maximumFrequency - DateTime.now().difference(last);
          if (remaining > Duration.zero) await _wait(remaining);
        }
        if (_disposed || generation != _generation) break;
        await performSeek(target);
        if (_disposed || generation != _generation) break;
        _lastCompletedTarget = target;
        _lastSeekAt = DateTime.now();
      }
      if (!completer.isCompleted) completer.complete();
    } on Object catch (error, stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    } finally {
      if (identical(_drainCompleter, completer)) _drainCompleter = null;
    }
  }

  Future<void> _wait(Duration duration) {
    final completer = Completer<void>();
    _waitCompleter = completer;
    _waitTimer = Timer(duration, completer.complete);
    return completer.future.whenComplete(() {
      if (identical(_waitCompleter, completer)) {
        _waitCompleter = null;
        _waitTimer = null;
      }
    });
  }
}
