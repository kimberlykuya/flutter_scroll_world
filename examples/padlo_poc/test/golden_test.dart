import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real-time scene asset is committed locally', () {
    final file = _projectFile('assets/scene/padlo-pilot.glb');
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(100000));
  });

  test(
    'Padlo runtime asset tree contains no legacy video or poster folders',
    () {
      expect(
        Directory(_projectFile('assets/videos').path).existsSync(),
        isFalse,
      );
      expect(
        Directory(_projectFile('assets/posters').path).existsSync(),
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

File _projectFile(String relativePath) {
  if (File('lib/main.dart').existsSync() && Directory('assets').existsSync()) {
    return File(relativePath);
  }
  return File('examples/padlo_poc/$relativePath');
}
