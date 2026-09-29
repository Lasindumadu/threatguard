import '../models/ml_prediction.dart';

abstract class MlClassifier {
  const MlClassifier();

  MlPrediction predict(List<double> features);
}
