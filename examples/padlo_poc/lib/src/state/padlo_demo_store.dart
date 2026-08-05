import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/demo_models.dart';

final class PadloDemoStore extends ChangeNotifier {
  static const _profileKey = 'padlo_demo_profile';
  static const _onboardingKey = 'padlo_onboarding_complete';
  static const _generatedReportKey = 'padlo_generated_report';
  static const _challengesKey = 'padlo_world_challenges';
  static const _selectedReportKey = 'padlo_selected_report';
  static const _checkpointKey = 'padlo_world_checkpoint';

  DemoPlayerProfile? _profile;
  bool _onboardingComplete = false;
  bool _generatedReport = false;
  final Set<String> _completedChallenges = <String>{};
  String _selectedReportId = featuredReport.id;
  String _worldCheckpoint = 'first-serve';

  DemoPlayerProfile? get profile => _profile;
  bool get isRegistered => _profile != null;
  bool get onboardingComplete => _onboardingComplete;
  bool get hasGeneratedReport => _generatedReport;
  Set<String> get completedChallenges =>
      Set<String>.unmodifiable(_completedChallenges);
  String get selectedReportId => _selectedReportId;
  String get worldCheckpoint => _worldCheckpoint;
  int get missionScore => (_completedChallenges.length * 8).clamp(0, 32);
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
    _completedChallenges
      ..clear()
      ..addAll(preferences.getStringList(_challengesKey) ?? const <String>[]);
    final selected = preferences.getString(_selectedReportKey);
    if (selected != null && reportById(selected) != null) {
      _selectedReportId = selected;
    }
    _worldCheckpoint = preferences.getString(_checkpointKey) ?? 'first-serve';
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

  Future<void> completeChallenge(String challengeId) async {
    if (!_completedChallenges.add(challengeId)) return;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _challengesKey,
      _completedChallenges.toList(growable: false)..sort(),
    );
  }

  Future<void> selectReport(String reportId) async {
    if (reportById(reportId) == null) {
      throw ArgumentError.value(reportId, 'reportId', 'not found');
    }
    if (_selectedReportId == reportId) return;
    _selectedReportId = reportId;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_selectedReportKey, reportId);
  }

  Future<void> setWorldCheckpoint(String sceneId) async {
    if (_worldCheckpoint == sceneId) return;
    _worldCheckpoint = sceneId;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_checkpointKey, sceneId);
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
    _completedChallenges.clear();
    _selectedReportId = featuredReport.id;
    _worldCheckpoint = 'first-serve';
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await Future.wait(<Future<bool>>[
      preferences.remove(_profileKey),
      preferences.remove(_onboardingKey),
      preferences.remove(_generatedReportKey),
      preferences.remove(_challengesKey),
      preferences.remove(_selectedReportKey),
      preferences.remove(_checkpointKey),
    ]);
  }
}
