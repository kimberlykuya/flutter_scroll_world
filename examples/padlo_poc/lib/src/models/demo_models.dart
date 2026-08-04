import 'dart:convert';

enum PlayerLevel { beginner, intermediate, advanced }

enum CourtSide { left, right, flexible }

enum PositioningFocus { netDepth, recoveryTiming, partnerSpacing, transitions }

final class DemoPlayerProfile {
  const DemoPlayerProfile({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.level,
    required this.preferredSide,
    required this.focus,
  });

  factory DemoPlayerProfile.fromJson(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    return DemoPlayerProfile(
      firstName: data['firstName'] as String,
      lastName: data['lastName'] as String,
      email: data['email'] as String,
      level: PlayerLevel.values.byName(data['level'] as String),
      preferredSide: CourtSide.values.byName(data['preferredSide'] as String),
      focus: PositioningFocus.values.byName(data['focus'] as String),
    );
  }

  final String firstName;
  final String lastName;
  final String email;
  final PlayerLevel level;
  final CourtSide preferredSide;
  final PositioningFocus focus;

  String get fullName => '$firstName $lastName';

  String toJson() => jsonEncode(<String, Object>{
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'level': level.name,
    'preferredSide': preferredSide.name,
    'focus': focus.name,
  });
}

final class PositioningMetric {
  const PositioningMetric({
    required this.label,
    required this.score,
    required this.change,
    required this.insight,
  });

  final String label;
  final int score;
  final int change;
  final String insight;
}

final class CourtCoordinate {
  const CourtCoordinate(this.x, this.y, this.intensity);

  final double x;
  final double y;
  final double intensity;
}

final class ReportMoment {
  const ReportMoment({
    required this.time,
    required this.title,
    required this.description,
    required this.severity,
  });

  final Duration time;
  final String title;
  final String description;
  final double severity;
}

final class NextMatchPlan {
  const NextMatchPlan({
    required this.correction,
    required this.drill,
    required this.cue,
  });

  final String correction;
  final String drill;
  final String cue;
}

final class GameReport {
  const GameReport({
    required this.id,
    required this.city,
    required this.dateLabel,
    required this.timeLabel,
    required this.team,
    required this.opponents,
    required this.result,
    required this.score,
    required this.change,
    required this.metrics,
    required this.heatmap,
    required this.moments,
    required this.plan,
  });

  final String id;
  final String city;
  final String dateLabel;
  final String timeLabel;
  final String team;
  final String opponents;
  final String result;
  final int score;
  final int change;
  final List<PositioningMetric> metrics;
  final List<CourtCoordinate> heatmap;
  final List<ReportMoment> moments;
  final NextMatchPlan plan;
}

final class MatchSummary {
  const MatchSummary({
    required this.reportId,
    required this.city,
    required this.dateLabel,
    required this.result,
    required this.score,
    required this.change,
  });

  final String reportId;
  final String city;
  final String dateLabel;
  final String result;
  final int score;
  final int change;
}

const featuredReport = GameReport(
  id: 'ljubljana-2026-08-02',
  city: 'Ljubljana',
  dateLabel: '2 Aug 2026',
  timeLabel: '19:30',
  team: 'Luka Novak & Nika Kovač',
  opponents: 'Žan Horvat & Maja Zupan',
  result: '6–4, 4–6, 10–8',
  score: 72,
  change: 6,
  metrics: <PositioningMetric>[
    PositioningMetric(
      label: 'Net depth',
      score: 78,
      change: 8,
      insight: 'You held an attacking distance in 7 of 10 net exchanges.',
    ),
    PositioningMetric(
      label: 'Recovery timing',
      score: 61,
      change: -2,
      insight: 'Your first recovery step was late after 6 bandejas.',
    ),
    PositioningMetric(
      label: 'Partner spacing',
      score: 83,
      change: 11,
      insight: 'You protected the middle with a consistent 3.2 m gap.',
    ),
    PositioningMetric(
      label: 'Transition decisions',
      score: 66,
      change: 4,
      insight: 'Two rushed advances opened space behind your pair.',
    ),
  ],
  heatmap: <CourtCoordinate>[
    CourtCoordinate(0.28, 0.25, 0.84),
    CourtCoordinate(0.34, 0.42, 0.68),
    CourtCoordinate(0.31, 0.68, 0.46),
    CourtCoordinate(0.66, 0.24, 0.72),
    CourtCoordinate(0.59, 0.51, 0.52),
  ],
  moments: <ReportMoment>[
    ReportMoment(
      time: Duration(minutes: 12, seconds: 14),
      title: 'Late recovery after bandeja',
      description:
          'The pair split to 5.1 m while the next ball entered the middle.',
      severity: 0.88,
    ),
    ReportMoment(
      time: Duration(minutes: 31, seconds: 8),
      title: 'Strong synchronized advance',
      description: 'Both players crossed the service line within 0.6 s.',
      severity: 0.28,
    ),
    ReportMoment(
      time: Duration(minutes: 48, seconds: 52),
      title: 'Transition forced too early',
      description:
          'The approach started before the lob cleared the back glass.',
      severity: 0.72,
    ),
  ],
  plan: NextMatchPlan(
    correction: 'Recover together before looking for the next attacking ball.',
    drill: 'Run 3 × 6 bandeja-and-recover repetitions with a 3 m partner rope.',
    cue: 'Hit. First step back. Find your partner.',
  ),
);

final demoReports = <GameReport>[
  featuredReport,
  GameReport(
    id: 'maribor-2026-07-27',
    city: 'Maribor',
    dateLabel: '27 Jul 2026',
    timeLabel: '18:00',
    team: 'Luka Novak & Nika Kovač',
    opponents: 'Tine Mlakar & Eva Kos',
    result: '6–3, 6–4',
    score: 66,
    change: 4,
    metrics: featuredReport.metrics,
    heatmap: featuredReport.heatmap,
    moments: featuredReport.moments,
    plan: featuredReport.plan,
  ),
  GameReport(
    id: 'koper-2026-07-19',
    city: 'Koper',
    dateLabel: '19 Jul 2026',
    timeLabel: '20:15',
    team: 'Luka Novak & Nika Kovač',
    opponents: 'Jan Vidmar & Sara Kralj',
    result: '4–6, 6–2, 8–10',
    score: 62,
    change: -1,
    metrics: featuredReport.metrics,
    heatmap: featuredReport.heatmap,
    moments: featuredReport.moments,
    plan: featuredReport.plan,
  ),
];

String enumLabel(Enum value) => value.name
    .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
    .replaceFirstMapped(
      RegExp(r'^.'),
      (match) => match.group(0)!.toUpperCase(),
    );
