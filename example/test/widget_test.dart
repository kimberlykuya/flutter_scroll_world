import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:scroll_world_example/main.dart';

void main() {
  testWidgets('shows the Kenya in Motion experience', (tester) async {
    await tester.pumpWidget(const KenyaInMotionApp());
    await tester.pump();

    expect(find.text('KENYA'), findsOneWidget);
    expect(find.text('NAIROBI'), findsNWidgets(2));
    expect(find.text('The city starts the journey'), findsOneWidget);
    expect(find.text('SCROLL TO JOURNEY THROUGH KENYA'), findsOneWidget);
  });

  testWidgets('keeps the 3D onboarding copy readable in portrait', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(540, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const KenyaInMotionApp());
    await tester.pump();

    expect(find.text('01'), findsOneWidget);
    expect(find.text('The city starts the journey'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps replay visible on the final page', (tester) async {
    await tester.pumpWidget(const KenyaInMotionApp());
    await tester.pump();
    await tester.tap(find.byTooltip('The river meets the ocean'));
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Replay the journey'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });
}
