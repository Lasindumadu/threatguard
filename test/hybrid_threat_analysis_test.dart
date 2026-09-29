import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/models/hybrid_threat_analysis.dart';
import 'package:threatguard/core/models/ml_feature_vector.dart';
import 'package:threatguard/core/models/ml_prediction.dart';
import 'package:threatguard/core/models/threat_analysis.dart';

void main() {
  test('stores rule analysis and ML prediction together', () {
    const ruleAnalysis = ThreatAnalysis(
      riskScore: 80,
      level: ThreatLevel.highRisk,
      type: ThreatType.phishing,
      indicators: [],
      detectedUrls: [],
      summary: 'Test phishing analysis',
      recommendation: 'Do not interact with the message.',
    );

    const mlPrediction = MlPrediction(
      type: MlThreatType.phishing,
      confidence: 0.92,
    );

    const hybridAnalysis = HybridThreatAnalysis(
      ruleAnalysis: ruleAnalysis,
      mlPrediction: mlPrediction,
      finalType: ThreatType.phishing,
    );

    expect(hybridAnalysis.ruleAnalysis.type, ThreatType.phishing);

    expect(hybridAnalysis.mlPrediction.type, MlThreatType.phishing);

    expect(hybridAnalysis.mlPrediction.confidence, 0.92);

    expect(hybridAnalysis.finalType, ThreatType.phishing);
  });
}
