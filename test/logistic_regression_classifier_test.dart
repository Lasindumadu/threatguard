import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/services/logistic_regression_classifier.dart';
import 'package:threatguard/core/services/ml_dataset_splitter.dart';
import 'package:threatguard/core/services/ml_feature_encoder.dart';
import 'package:threatguard/core/services/ml_training_dataset.dart';

void main() {
  test('trains logistic regression classifier', () {
    const dataset = MlTrainingDataset();
    const splitter = MlDatasetSplitter();
    const encoder = MlFeatureEncoder();

    final examples = dataset.build();
    final split = splitter.split(examples);

    final trainingVectors = split.training
        .map((example) => encoder.encode(example.features))
        .toList();

    final classifier = LogisticRegressionClassifier.train(
      examples: split.training,
      featureVectors: trainingVectors,
      epochs: 1000,
      learningRate: 0.05,
      l2Penalty: 0.001,
    );

    final testVector = encoder.encode(split.testing.first.features);

    final prediction = classifier.predict(testVector);

    expect(prediction.type, isNotNull);
    expect(prediction.confidence, greaterThanOrEqualTo(0.0));
    expect(prediction.confidence, lessThanOrEqualTo(1.0));
  });
}
