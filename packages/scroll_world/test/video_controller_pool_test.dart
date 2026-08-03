import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_world/scroll_world.dart';
import 'package:scroll_world/src/controllers/video_controller_pool.dart';
import 'package:scroll_world/src/models/scroll_world_timeline.dart';

final class PoolDriverFactory implements ScrollVideoDriverFactory {
  PoolDriverFactory({this.failFirstInitialization = false});

  final bool failFirstInitialization;
  int created = 0;
  int disposed = 0;

  @override
  ScrollVideoDriver create(ScrollWorldSource source) {
    created++;
    return PoolDriver(
      failInitialization: failFirstInitialization && created == 1,
      onDispose: () => disposed++,
    );
  }
}

final class PoolDriver implements ScrollVideoDriver {
  PoolDriver({required this.failInitialization, required this.onDispose});

  final bool failInitialization;
  final VoidCallback onDispose;
  bool ready = false;

  @override
  Duration get duration => const Duration(seconds: 2);
  @override
  bool get isReady => ready;
  @override
  Widget buildView({BoxFit fit = BoxFit.cover}) => const SizedBox.shrink();

  @override
  Future<void> initialize() async {
    if (failInitialization) throw StateError('planned failure');
    ready = true;
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> seekTo(Duration position) async {}
  @override
  Future<void> dispose() async => onDispose();
}

VideoControllerPool pool(PoolDriverFactory factory, {int retries = 1}) =>
    VideoControllerPool(
      factory: factory,
      seekTolerance: Duration.zero,
      maximumSeekFrequency: Duration.zero,
      initializationRetryCount: retries,
    );

void main() {
  const source = ScrollWorldSource.asset('video.mp4');

  test('evicts media no longer in the desired radius', () async {
    final factory = PoolDriverFactory();
    final controllerPool = pool(factory);
    controllerPool.reconcile(<ScrollWorldMediaKey, ScrollWorldSource>{
      const ScrollWorldMediaKey.scene(0): source,
    });
    await Future<void>.delayed(Duration.zero);
    controllerPool.reconcile(<ScrollWorldMediaKey, ScrollWorldSource>{
      const ScrollWorldMediaKey.scene(1): source,
    });
    await Future<void>.delayed(Duration.zero);

    expect(controllerPool.debugSnapshot.keys, <String>{'scene:1'});
    expect(factory.disposed, 1);
    controllerPool.dispose();
  });

  test('recreates a failed driver and succeeds within retry policy', () async {
    final factory = PoolDriverFactory(failFirstInitialization: true);
    final controllerPool = pool(factory);
    controllerPool.reconcile(<ScrollWorldMediaKey, ScrollWorldSource>{
      const ScrollWorldMediaKey.scene(0): source,
    });
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(factory.created, 2);
    expect(factory.disposed, 1);
    expect(controllerPool.debugSnapshot.initializedCount, 1);
    controllerPool.dispose();
  });
}
