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

  ThreatLevel get finalLevel {
    if (finalType == ThreatType.legitimate) {
      return ThreatLevel.safe;
    }

    if (ruleAnalysis.type == ThreatType.legitimate) {
      return ThreatLevel.suspicious;
    }

    return ruleAnalysis.level;
  }
}
