import 'package:flutter_test/flutter_test.dart';
import 'package:padlo_poc/src/routing/app_router.dart';

void main() {
  test('legacy product links resolve to the real-time pilot anchor', () {
    expect(padloPilotRedirect('/onboarding'), isNull);
    expect(padloPilotRedirect('/'), isNull);
    expect(
      padloPilotRedirect('/app/reports/luka-ljubljana'),
      '/onboarding?from=%2Fapp%2Freports%2Fluka-ljubljana',
    );
  });
}
