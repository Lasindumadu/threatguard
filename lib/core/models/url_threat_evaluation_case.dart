import 'threat_analysis.dart';
import 'url_analysis.dart';

class UrlThreatEvaluationCase {
  final String id;
  final String message;
  final UrlSignalType expectedUrlSignal;
  final ThreatType expectedThreatType;
  final ThreatLevel expectedThreatLevel;

  const UrlThreatEvaluationCase({
    required this.id,
    required this.message,
    required this.expectedUrlSignal,
    required this.expectedThreatType,
    required this.expectedThreatLevel,
  });
}
