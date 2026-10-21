import 'threat_analysis.dart';

class EvaluationCase {
  final String id;
  final String message;
  final ThreatType expectedType;
  final ThreatLevel expectedLevel;

  /// Scenario family for group-aware evaluation splitting.
  ///
  /// All cases sharing a family must land in the same fold so that
  /// near-duplicate scenario templates cannot leak from training into held-out
  /// evaluation. A `null` family means the case is a unique singleton (its own
  /// one-case family). Families are assigned by hand in
  /// [EvaluationDataset] and documented there; uncertain assignments are left
  /// `null` rather than guessed.
  final String? scenarioFamily;

  const EvaluationCase({
    required this.id,
    required this.message,
    required this.expectedType,
    required this.expectedLevel,
    this.scenarioFamily,
  });
}
