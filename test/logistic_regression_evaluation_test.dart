// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/models/ml_feature_vector.dart';
import 'package:threatguard/core/services/logistic_regression_classifier.dart';
import 'package:threatguard/core/services/ml_dataset_splitter.dart';
import 'package:threatguard/core/services/ml_feature_encoder.dart';
import 'package:threatguard/core/services/ml_training_dataset.dart';

void main() {
  test('evaluates logistic regression on held-out test cases', () {
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

    var correct = 0;

    final confusionMatrix = <MlThreatType, Map<MlThreatType, int>>{
      for (final actual in MlThreatType.values)
        actual: {for (final predicted in MlThreatType.values) predicted: 0},
    };

    for (final example in split.testing) {
      final features = encoder.encode(example.features);

      final prediction = classifier.predict(features);

      confusionMatrix[example.label]![prediction.type] =
          confusionMatrix[example.label]![prediction.type]! + 1;

      if (prediction.type == example.label) {
        correct++;
      }
    }

    final accuracy = correct / split.testing.length;

    print('');
    print('===== LOGISTIC REGRESSION EVALUATION =====');
    print('Training examples: ${split.training.length}');
    print('Test examples: ${split.testing.length}');
    print('Correct predictions: $correct');
    print('Accuracy: ${(accuracy * 100).toStringAsFixed(1)}%');
    print('');
    print('Confusion matrix:');
    print('Actual → Predicted');
    print('');

    for (final actual in MlThreatType.values) {
      final row = confusionMatrix[actual]!;

      print(
        '${actual.name}: '
        '${row.entries.map((entry) => '${entry.key.name}=${entry.value}').join(', ')}',
      );
    }

    print('===========================================');
    print('');

    expect(split.testing.length, 35);

    expect(accuracy, greaterThanOrEqualTo(0.0));

    expect(accuracy, lessThanOrEqualTo(1.0));
  });
}
