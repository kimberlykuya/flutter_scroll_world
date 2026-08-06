import 'package:flutter_test/flutter_test.dart';
import 'package:padlo_poc/src/world/padlo_scene_runtime.dart';

void main() {
  test('runtime camera converts Blender Z-up coordinates to glTF Y-up', () {
    final runtime = PadloSceneRuntime.withoutRenderer();
    addTearDown(runtime.dispose);

    final camera = runtime.cameraFor(0);

    expect(camera.position.x, closeTo(7.5, 0.001));
    expect(camera.position.y, closeTo(9.5, 0.001));
    expect(camera.position.z, closeTo(24, 0.001));
    expect(camera.target.x, closeTo(0, 0.001));
    expect(camera.target.y, closeTo(1.2, 0.001));
    expect(camera.target.z, closeTo(12, 0.001));
  });

  test('pilot camera remains above the court throughout the journey', () {
    final runtime = PadloSceneRuntime.withoutRenderer();
    addTearDown(runtime.dispose);

    for (var step = 0; step <= 100; step++) {
      final camera = runtime.cameraFor(step / 100);
      expect(camera.position.y, greaterThan(4.4));
      expect(camera.forward.y, lessThan(0));
    }
  });
}
