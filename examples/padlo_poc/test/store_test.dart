import 'package:flutter_test/flutter_test.dart';
import 'package:padlo_poc/src/models/demo_models.dart';
import 'package:padlo_poc/src/state/padlo_demo_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
    'registration, generated report, restoration, and reset persist',
    () async {
      final store = PadloDemoStore();
      await store.load();
      expect(store.isRegistered, isFalse);

      const profile = DemoPlayerProfile(
        firstName: 'Luka',
        lastName: 'Novak',
        email: 'luka@example.com',
        level: PlayerLevel.intermediate,
        preferredSide: CourtSide.right,
        focus: PositioningFocus.recoveryTiming,
      );
      await store.register(profile);
      await store.markReportGenerated();
      await store.completeChallenge('pressure-zone');
      await store.completeChallenge('recover-first');
      await store.selectReport(demoReports.last.id);
      await store.setWorldCheckpoint('report-vault');

      final restored = PadloDemoStore();
      await restored.load();
      expect(restored.profile?.fullName, 'Luka Novak');
      expect(restored.onboardingComplete, isTrue);
      expect(restored.hasGeneratedReport, isTrue);
      expect(restored.reportById(featuredReport.id), same(featuredReport));
      expect(
        restored.completedChallenges,
        containsAll(<String>['pressure-zone', 'recover-first']),
      );
      expect(restored.missionScore, 16);
      expect(restored.selectedReportId, demoReports.last.id);
      expect(restored.worldCheckpoint, 'report-vault');

      await restored.reset();
      expect(restored.isRegistered, isFalse);
      expect(restored.onboardingComplete, isFalse);
      expect(restored.hasGeneratedReport, isFalse);
      expect(restored.completedChallenges, isEmpty);
      expect(restored.selectedReportId, featuredReport.id);
      expect(restored.worldCheckpoint, 'first-serve');
    },
  );

  test('corrupt persisted profile is rejected safely', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'padlo_demo_profile': '{not-json',
    });
    final store = PadloDemoStore();

    await store.load();

    expect(store.isRegistered, isFalse);
  });
}
