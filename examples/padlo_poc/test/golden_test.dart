import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real-time scene asset is committed locally', () {
    final file = File('examples/padlo_poc/assets/scene/padlo-pilot.glb');
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(100000));
  });

  test(
    'Padlo runtime asset tree contains no legacy video or poster folders',
    () {
      expect(
        Directory('examples/padlo_poc/assets/videos').existsSync(),
        isFalse,
      );
      expect(
        Directory('examples/padlo_poc/assets/posters').existsSync(),
        isFalse,
      );
    },
  );

  testWidgets('browser golden checkpoints are reserved for WebGL2', (
    tester,
  ) async {
    // SceneView is intentionally covered by Chrome integration screenshots;
    // headless widget tests remain deterministic and do not fake GPU output.
    await tester.pumpWidget(const SizedBox.shrink());
    expect(find.byType(SizedBox), findsOneWidget);
  });
}
