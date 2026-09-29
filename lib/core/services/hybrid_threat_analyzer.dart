import '../models/hybrid_threat_analysis.dart';
import '../models/ml_feature_vector.dart';
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

  HybridThreatAnalysis analyze(String message) {
    final ruleAnalysis = threatAnalyzer.analyze(message);

    final features = featureExtractor.extract(message: message);

    final encodedFeatures = featureEncoder.encode(features);

    final mlPrediction = classifier.predict(encodedFeatures);

    final finalType = _resolveFinalType(
      ruleType: ruleAnalysis.type,
      mlType: mlPrediction.type,
    );

    return HybridThreatAnalysis(
      ruleAnalysis: ruleAnalysis,
      mlPrediction: mlPrediction,
      finalType: finalType,
    );
  }

  ThreatType _resolveFinalType({
    required ThreatType ruleType,
    required MlThreatType mlType,
  }) {
    if (ruleType != ThreatType.legitimate) {
      return ruleType;
    }

    return _toThreatType(mlType);
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
