import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/scroll_world_error.dart';
import '../models/scroll_world_source.dart';
import '../models/scroll_world_timeline.dart';
import '../playback/scroll_video_driver.dart';
import 'seek_scheduler.dart';

@immutable
final class ScrollWorldDriverDebugSnapshot {
  const ScrollWorldDriverDebugSnapshot({
    required this.initializedCount,
    required this.keys,
    this.positions = const <String, double>{},
  });

  final int initializedCount;
  final Set<String> keys;
  final Map<String, double> positions;
}

final class ScrollWorldPoolEntry {
  ScrollWorldPoolEntry({
    required this.key,
    required this.source,
    required this.driver,
    required this.scheduler,
  });

  final ScrollWorldMediaKey key;
  final ScrollWorldSource source;
  ScrollVideoDriver driver;
  final SeekScheduler scheduler;

  bool initializing = false;
  bool ready = false;
  bool hasFrame = false;
  bool disposed = false;
  Object? error;
  int generation = 0;
  double lastCompletedProgress = 0;

  bool get isLoading => initializing && !ready;
}

/// Owns the bounded set of playback drivers around the active segment.
final class VideoControllerPool extends ChangeNotifier {
  VideoControllerPool({
    required ScrollVideoDriverFactory factory,
    required this.seekTolerance,
    required this.maximumSeekFrequency,
    required this.initializationRetryCount,
    this.onError,
  }) : _factory = factory;

  final ScrollVideoDriverFactory _factory;
  final Duration seekTolerance;
  final Duration maximumSeekFrequency;
  final int initializationRetryCount;
  final ScrollWorldErrorCallback? onError;
  final Map<ScrollWorldMediaKey, ScrollWorldPoolEntry> _entries = {};
  bool _disposed = false;

  ScrollWorldPoolEntry? entryFor(ScrollWorldMediaKey key) => _entries[key];

  ScrollWorldDriverDebugSnapshot get debugSnapshot =>
      ScrollWorldDriverDebugSnapshot(
        initializedCount: _entries.values.where((entry) => entry.ready).length,
        keys: _entries.keys.map((key) => key.value).toSet(),
        positions: Map<String, double>.unmodifiable(
          _entries.map(
            (key, entry) => MapEntry(key.value, entry.lastCompletedProgress),
          ),
        ),
      );

  void reconcile(Map<ScrollWorldMediaKey, ScrollWorldSource> desired) {
    if (_disposed) return;
    var changed = false;
    final obsolete = _entries.entries
        .where(
          (entry) =>
              !desired.containsKey(entry.key) ||
              desired[entry.key] != entry.value.source,
        )
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final key in obsolete) {
      final entry = _entries.remove(key);
      if (entry != null) {
        changed = true;
        unawaited(_disposeEntry(entry));
      }
    }

    for (final MapEntry(key: key, value: source) in desired.entries) {
      if (_entries.containsKey(key)) continue;
      final entry = ScrollWorldPoolEntry(
        key: key,
        source: source,
        driver: _factory.create(source),
        scheduler: SeekScheduler(
          tolerance: seekTolerance,
          maximumFrequency: maximumSeekFrequency,
        ),
      );
      _entries[key] = entry;
      changed = true;
      unawaited(_initialize(entry));
    }
    if (changed) notifyListeners();
  }

  Future<void> seek(ScrollWorldMediaKey key, double progress) async {
    final entry = _entries[key];
    if (entry == null || !entry.ready || entry.disposed) return;
    final duration = entry.driver.duration;
    if (duration <= Duration.zero) return;
    final safeProgress = progress.clamp(0.0, 0.999).toDouble();
    final target = Duration(
      microseconds: (duration.inMicroseconds * safeProgress).round(),
    );
    final generation = entry.generation;
    try {
      await entry.scheduler.request(target, entry.driver.seekTo);
      if (entry.disposed || entry.generation != generation || _disposed) return;
      entry.lastCompletedProgress = safeProgress;
      if (!entry.hasFrame) {
        entry.hasFrame = true;
        notifyListeners();
      }
    } on Object catch (error, stackTrace) {
      if (!entry.disposed) {
        entry.error = error;
        onError?.call(
          ScrollWorldPlaybackError(
            mediaKey: key.value,
            source: entry.source,
            error: error,
            stackTrace: stackTrace,
            attempt: initializationRetryCount + 1,
          ),
        );
        notifyListeners();
      }
    }
  }

  Future<void> pauseAll() async {
    await Future.wait(_entries.values.map((entry) => entry.driver.pause()));
  }

  Future<void> primeAll() async {
    await Future.wait(
      _entries.values.map((entry) async {
        final driver = entry.driver;
        if (entry.ready && driver is ScrollVideoPrimingDriver) {
          await (driver as ScrollVideoPrimingDriver).prime();
        }
      }),
    );
  }

  Future<void> releaseAll() async {
    final entries = _entries.values.toList(growable: false);
    _entries.clear();
    await Future.wait(entries.map(_disposeEntry));
    if (!_disposed) notifyListeners();
  }

  Future<void> _initialize(ScrollWorldPoolEntry entry) async {
    entry.initializing = true;
    notifyListeners();
    for (var attempt = 1; attempt <= initializationRetryCount + 1; attempt++) {
      try {
        await entry.driver.initialize();
        if (entry.disposed || _disposed) return;
        entry
          ..initializing = false
          ..ready = true
          ..error = null;
        notifyListeners();
        return;
      } on Object catch (error, stackTrace) {
        if (entry.disposed || _disposed) return;
        entry.error = error;
        if (attempt > initializationRetryCount) {
          entry.initializing = false;
          onError?.call(
            ScrollWorldPlaybackError(
              mediaKey: entry.key.value,
              source: entry.source,
              error: error,
              stackTrace: stackTrace,
              attempt: attempt,
            ),
          );
          notifyListeners();
          return;
        }
        await entry.driver.dispose();
        if (entry.disposed || _disposed) return;
        entry.driver = _factory.create(entry.source);
      }
    }
  }

  Future<void> _disposeEntry(ScrollWorldPoolEntry entry) async {
    if (entry.disposed) return;
    entry.disposed = true;
    entry.generation++;
    entry.scheduler.dispose();
    await entry.driver.dispose();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final entries = _entries.values.toList(growable: false);
    _entries.clear();
    for (final entry in entries) {
      unawaited(_disposeEntry(entry));
    }
    super.dispose();
  }
}
