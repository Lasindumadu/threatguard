import 'ml_feature_vector.dart';

class MlTrainingExample {
  final MlFeatureVector features;
  final MlThreatType label;

  const MlTrainingExample({required this.features, required this.label});
}
