import 'ml_prediction.dart';
import 'threat_analysis.dart';

class HybridThreatAnalysis {
  final ThreatAnalysis ruleAnalysis;
  final MlPrediction mlPrediction;
  final ThreatType finalType;

  const HybridThreatAnalysis({
    required this.ruleAnalysis,
    required this.mlPrediction,
    required this.finalType,
  });
}
