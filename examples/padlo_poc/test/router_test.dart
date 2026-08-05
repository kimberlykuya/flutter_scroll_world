import 'package:flutter_test/flutter_test.dart';
import 'package:padlo_poc/src/models/demo_models.dart';
import 'package:padlo_poc/src/routing/app_router.dart';
import 'package:padlo_poc/src/state/padlo_demo_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registered refresh restores the world checkpoint anchor', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'padlo_onboarding_complete': true,
      'padlo_demo_profile': const DemoPlayerProfile(
        firstName: 'Luka',
        lastName: 'Novak',
        email: 'luka@example.com',
        level: PlayerLevel.intermediate,
        preferredSide: CourtSide.right,
        focus: PositioningFocus.recoveryTiming,
      ).toJson(),
      'padlo_selected_report': demoReports.last.id,
      'padlo_world_checkpoint': 'replay-arena',
    });
    final store = PadloDemoStore();
    await store.load();
    final router = buildPadloRouter(store);
    addTearDown(router.dispose);
    addTearDown(store.dispose);

    expect(
      router.routeInformationProvider.value.uri.path,
      '/app/reports/${demoReports.last.id}',
    );
  });

  test('unregistered state cannot restore a protected checkpoint', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'padlo_onboarding_complete': true,
      'padlo_world_checkpoint': 'replay-arena',
    });
    final store = PadloDemoStore();
    await store.load();
    final router = buildPadloRouter(store);
    addTearDown(router.dispose);
    addTearDown(store.dispose);

    expect(router.routeInformationProvider.value.uri.path, '/register');
  });
}
