import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_world/src/controllers/scroll_progress_smoother.dart';

void main() {
  test('0.18 smoothing converges without overshooting in either direction', () {
    var forward = 0.0;
    var reverse = 1.0;
    for (var frame = 0; frame < 60; frame += 1) {
      final nextForward = interpolateScrollProgress(
        displayed: forward,
        target: 1,
        factor: 0.18,
      );
      final nextReverse = interpolateScrollProgress(
        displayed: reverse,
        target: 0,
        factor: 0.18,
      );
      expect(nextForward, inInclusiveRange(forward, 1));
      expect(nextReverse, inInclusiveRange(0, reverse));
      forward = nextForward;
      reverse = nextReverse;
    }

    expect(forward, closeTo(1, 0.00001));
    expect(reverse, closeTo(0, 0.00001));
  });
}
