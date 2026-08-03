import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_world/src/controllers/seek_scheduler.dart';

void main() {
  test('coalesces overlapping requests to the latest target', () async {
    final scheduler = SeekScheduler(
      tolerance: Duration.zero,
      maximumFrequency: Duration.zero,
    );
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final performed = <Duration>[];
    var inFlight = 0;
    var maximumInFlight = 0;

    Future<void> seek(Duration target) async {
      inFlight += 1;
      maximumInFlight = maximumInFlight < inFlight ? inFlight : maximumInFlight;
      performed.add(target);
      if (performed.length == 1) {
        firstStarted.complete();
        await releaseFirst.future;
      }
      inFlight -= 1;
    }

    final first = scheduler.request(const Duration(milliseconds: 10), seek);
    await firstStarted.future;
    unawaited(scheduler.request(const Duration(milliseconds: 20), seek));
    unawaited(scheduler.request(const Duration(milliseconds: 30), seek));
    releaseFirst.complete();
    await first;

    expect(performed, <Duration>[
      const Duration(milliseconds: 10),
      const Duration(milliseconds: 30),
    ]);
    expect(maximumInFlight, 1);
  });

  test('suppresses targets inside tolerance', () async {
    final scheduler = SeekScheduler(
      tolerance: const Duration(milliseconds: 30),
      maximumFrequency: Duration.zero,
    );
    var calls = 0;
    Future<void> seek(Duration target) async => calls++;

    await scheduler.request(const Duration(milliseconds: 100), seek);
    await scheduler.request(const Duration(milliseconds: 120), seek);
    expect(calls, 1);
  });

  test('drops queued work after invalidation', () async {
    final scheduler = SeekScheduler(
      tolerance: Duration.zero,
      maximumFrequency: Duration.zero,
    );
    final started = Completer<void>();
    final release = Completer<void>();
    final performed = <Duration>[];

    Future<void> seek(Duration target) async {
      performed.add(target);
      started.complete();
      await release.future;
    }

    final first = scheduler.request(const Duration(milliseconds: 10), seek);
    await started.future;
    unawaited(scheduler.request(const Duration(milliseconds: 20), seek));
    scheduler.invalidate();
    release.complete();
    await first;

    expect(performed, <Duration>[const Duration(milliseconds: 10)]);
  });
}
