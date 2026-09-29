import 'ml_feature_vector.dart';

class MlPrediction {
  final MlThreatType type;
  final double confidence;

  const MlPrediction({required this.type, required this.confidence});
}
