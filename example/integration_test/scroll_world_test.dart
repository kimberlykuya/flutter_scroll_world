import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:scroll_world_example/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real media survives forward and reverse scrolling', (
    tester,
  ) async {
    await tester.pumpWidget(const KenyaInMotionApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('The city starts the journey'), findsOneWidget);

    await tester.drag(find.byType(KenyaInMotionPage), const Offset(0, -1200));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(KenyaInMotionPage), const Offset(0, 1200));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('final action replays the real journey to Nairobi', (
    tester,
  ) async {
    await tester.pumpWidget(const KenyaInMotionApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.byTooltip('The river meets the ocean'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Replay the journey'), findsOneWidget);

    await tester.tap(find.text('Replay the journey'));
    for (var frame = 0; frame < 120; frame += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('The city starts the journey'), findsOneWidget);
    expect(find.text('SCROLL TO JOURNEY THROUGH KENYA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
