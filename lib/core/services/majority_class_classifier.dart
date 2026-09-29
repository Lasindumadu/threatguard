import '../models/ml_feature_vector.dart';
import '../models/ml_prediction.dart';
import 'ml_classifier.dart';

class MajorityClassClassifier implements MlClassifier {
  final MlThreatType majorityType;

  const MajorityClassClassifier({required this.majorityType});

  @override
  MlPrediction predict(List<double> features) {
    return MlPrediction(type: majorityType, confidence: 0.0);
  }
}
