import 'threat_signal.dart';

class ThreatRule {
  final String id;
  final String title;
  final String description;
  final List<String> patterns;
  final int scoreContribution;
  final ThreatSignalCategory category;
  final ThreatSignalStrength strength;

  const ThreatRule({
    required this.id,
    required this.title,
    required this.description,
    required this.patterns,
    required this.scoreContribution,
    required this.category,
    required this.strength,
  });
}
