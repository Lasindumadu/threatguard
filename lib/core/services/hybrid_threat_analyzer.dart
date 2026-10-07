import '../models/hybrid_threat_analysis.dart';
import '../models/ml_feature_vector.dart';
import '../models/ml_prediction.dart';
import '../models/threat_analysis.dart';
import 'ml_classifier.dart';
import 'ml_feature_encoder.dart';
import 'ml_feature_extractor.dart';
import 'threat_analyzer.dart';

class HybridThreatAnalyzer {
  final ThreatAnalyzer threatAnalyzer;
  final MlFeatureExtractor featureExtractor;
  final MlFeatureEncoder featureEncoder;
  final MlClassifier classifier;

  const HybridThreatAnalyzer({
    this.threatAnalyzer = const ThreatAnalyzer(),
    this.featureExtractor = const MlFeatureExtractor(),
    this.featureEncoder = const MlFeatureEncoder(),
    required this.classifier,
  });

  // Tunable. Re-calibrate these on a real held-out dataset.
  static const double mlOverrideThreshold = 0.75;
  static const double mlDowngradeThreshold = 0.90;
  static const int strongRuleScore = 50;
  static const int weakRuleScore = 30;

  HybridThreatAnalysis analyze(String message) {
    final ruleAnalysis = threatAnalyzer.analyze(message);

    final features = featureExtractor.extract(message: message);
    final encodedFeatures = featureEncoder.encode(features);
    final mlPrediction = classifier.predict(encodedFeatures);

    final finalType = _resolveFinalType(
      ruleAnalysis: ruleAnalysis,
      ml: mlPrediction,
    );

    return HybridThreatAnalysis(
      ruleAnalysis: ruleAnalysis,
      mlPrediction: mlPrediction,
      finalType: finalType,
    );
  }

  ThreatType _resolveFinalType({
    required ThreatAnalysis ruleAnalysis,
    required MlPrediction ml,
  }) {
    final ruleType = ruleAnalysis.type;
    final mlType = _toThreatType(ml.type);
    final score = ruleAnalysis.riskScore;

    // Both systems agree.
    if (ruleType == mlType) {
      return ruleType;
    }

    // Rules found nothing: accept the ML only when sufficiently confident.
    if (ruleType == ThreatType.legitimate) {
      return ml.confidence >= mlOverrideThreshold
          ? mlType
          : ThreatType.legitimate;
    }

    // Rules found a threat, but ML says legitimate.
    // Only clear weak rule hits with very high ML confidence.
    if (mlType == ThreatType.legitimate) {
      final clear =
          score < weakRuleScore && ml.confidence >= mlDowngradeThreshold;

      return clear ? ThreatType.legitimate : ruleType;
    }

    // Both systems detect a threat but disagree on its category.
    // Strong rule evidence wins; otherwise sufficiently confident ML wins.
    if (score >= strongRuleScore) {
      return ruleType;
    }

    return ml.confidence >= mlOverrideThreshold ? mlType : ruleType;
  }

  ThreatType _toThreatType(MlThreatType type) {
    switch (type) {
      case MlThreatType.legitimate:
        return ThreatType.legitimate;
      case MlThreatType.spam:
        return ThreatType.spam;
      case MlThreatType.phishing:
        return ThreatType.phishing;
      case MlThreatType.scam:
        return ThreatType.scam;
      case MlThreatType.socialEngineering:
        return ThreatType.socialEngineering;
    }
  }
}
