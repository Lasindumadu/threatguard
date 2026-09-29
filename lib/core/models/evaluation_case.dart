import 'threat_analysis.dart';

class EvaluationCase {
  final String id;
  final String message;
  final ThreatType expectedType;
  final ThreatLevel expectedLevel;

  const EvaluationCase({
    required this.id,
    required this.message,
    required this.expectedType,
    required this.expectedLevel,
  });
}
