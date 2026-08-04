import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/demo_models.dart';

final class PadloDemoStore extends ChangeNotifier {
  static const _profileKey = 'padlo_demo_profile';
  static const _onboardingKey = 'padlo_onboarding_complete';
  static const _generatedReportKey = 'padlo_generated_report';

  DemoPlayerProfile? _profile;
  bool _onboardingComplete = false;
  bool _generatedReport = false;

  DemoPlayerProfile? get profile => _profile;
  bool get isRegistered => _profile != null;
  bool get onboardingComplete => _onboardingComplete;
  bool get hasGeneratedReport => _generatedReport;
  List<GameReport> get reports => demoReports;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final profileJson = preferences.getString(_profileKey);
    if (profileJson != null) {
      try {
        _profile = DemoPlayerProfile.fromJson(profileJson);
      } on Object {
        await preferences.remove(_profileKey);
      }
    }
    _onboardingComplete = preferences.getBool(_onboardingKey) ?? false;
    _generatedReport = preferences.getBool(_generatedReportKey) ?? false;
  }

  Future<void> completeOnboarding() async {
    _onboardingComplete = true;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingKey, true);
  }

  Future<void> register(DemoPlayerProfile profile) async {
    _profile = profile;
    _onboardingComplete = true;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await Future.wait(<Future<bool>>[
      preferences.setString(_profileKey, profile.toJson()),
      preferences.setBool(_onboardingKey, true),
    ]);
  }

  Future<void> markReportGenerated() async {
    if (_generatedReport) return;
    _generatedReport = true;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_generatedReportKey, true);
  }

  GameReport? reportById(String id) {
    for (final report in reports) {
      if (report.id == id) return report;
    }
    return null;
  }

  Future<void> reset() async {
    _profile = null;
    _onboardingComplete = false;
    _generatedReport = false;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await Future.wait(<Future<bool>>[
      preferences.remove(_profileKey),
      preferences.remove(_onboardingKey),
      preferences.remove(_generatedReportKey),
    ]);
  }
}
