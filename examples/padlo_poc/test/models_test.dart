import 'package:flutter_test/flutter_test.dart';
import 'package:padlo_poc/src/models/demo_models.dart';

void main() {
  test('profile JSON round-trip preserves Slovenian demo choices', () {
    const profile = DemoPlayerProfile(
      firstName: 'Luka',
      lastName: 'Novak',
      email: 'luka@example.com',
      level: PlayerLevel.intermediate,
      preferredSide: CourtSide.right,
      focus: PositioningFocus.recoveryTiming,
    );

    final restored = DemoPlayerProfile.fromJson(profile.toJson());

    expect(restored.fullName, 'Luka Novak');
    expect(restored.level, PlayerLevel.intermediate);
    expect(restored.preferredSide, CourtSide.right);
    expect(restored.focus, PositioningFocus.recoveryTiming);
  });

  test('seed reports are deterministic and use city-only locations', () {
    expect(demoReports.map((report) => report.city), <String>[
      'Ljubljana',
      'Maribor',
      'Koper',
    ]);
    expect(featuredReport.score, 72);
    expect(featuredReport.metrics.map((metric) => metric.score), <int>[
      78,
      61,
      83,
      66,
    ]);
    expect(featuredReport.team, contains('Kovač'));
    expect(featuredReport.opponents, contains('Žan'));
  });

  test('enum labels convert camel case into readable copy', () {
    expect(enumLabel(PositioningFocus.recoveryTiming), 'Recovery Timing');
    expect(enumLabel(CourtSide.right), 'Right');
  });
}
