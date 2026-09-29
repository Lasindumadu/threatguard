import '../models/hybrid_threat_analysis.dart';
import '../models/message_source.dart';
import '../models/threat_message.dart';
import 'hybrid_threat_analyzer.dart';

class SmsThreatAnalyzer {
  final HybridThreatAnalyzer analyzer;

  const SmsThreatAnalyzer({required this.analyzer});

  HybridThreatAnalysis analyze(ThreatMessage message) {
    if (message.source != MessageSource.sms) {
      throw ArgumentError(
        'SmsThreatAnalyzer only accepts messages with source = MessageSource.sms.',
      );
    }

    return analyzer.analyze(message.body);
  }
}
