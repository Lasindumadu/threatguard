import '../models/ml_feature_vector.dart';
import '../models/ml_training_example.dart';
import 'evaluation_dataset.dart';
import 'ml_feature_extractor.dart';

class MlTrainingDataset {
  final MlFeatureExtractor extractor;

  const MlTrainingDataset({this.extractor = const MlFeatureExtractor()});

  List<MlTrainingExample> build() {
    return EvaluationDataset.cases.map((evaluationCase) {
      final features = extractor.extract(
        caseId: evaluationCase.id,
        message: evaluationCase.message,
      );

      return MlTrainingExample(
        features: features,
        label: _toMlThreatType(evaluationCase.expectedType),
      );
    }).toList();
  }

  MlThreatType _toMlThreatType(dynamic threatType) {
    switch (threatType.toString().split('.').last) {
      case 'legitimate':
        return MlThreatType.legitimate;
      case 'spam':
        return MlThreatType.spam;
      case 'phishing':
        return MlThreatType.phishing;
      case 'scam':
        return MlThreatType.scam;
      case 'socialEngineering':
        return MlThreatType.socialEngineering;
      default:
        throw StateError('Unsupported threat type: $threatType');
    }
  }
}
