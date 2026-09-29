import 'url_analysis.dart';

class UrlEvaluationCase {
  final String id;
  final String message;
  final UrlSignalType expectedSignal;
  final bool shouldDetectSignal;

  const UrlEvaluationCase({
    required this.id,
    required this.message,
    required this.expectedSignal,
    required this.shouldDetectSignal,
  });
}
