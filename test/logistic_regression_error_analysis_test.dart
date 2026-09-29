// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/services/logistic_regression_classifier.dart';
import 'package:threatguard/core/services/ml_dataset_splitter.dart';
import 'package:threatguard/core/services/ml_feature_encoder.dart';
import 'package:threatguard/core/services/ml_training_dataset.dart';

void main() {
  test('prints held-out classification errors', () {
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

    print('');
    print('===== ML ERROR ANALYSIS =====');

    var errorCount = 0;

    for (final example in split.testing) {
      final features = encoder.encode(example.features);
      final prediction = classifier.predict(features);

      if (prediction.type != example.label) {
        errorCount++;

        print('');
        print('Case: ${example.features.caseId}');
        print('Expected: ${example.label.name}');
        print('Predicted: ${prediction.type.name}');
        print(
          'Confidence: '
          '${prediction.confidence.toStringAsFixed(4)}',
        );
        print('Feature vector: $features');
      }
    }

    print('');
    print('Total errors: $errorCount');
    print('============================');
    print('');

    expect(errorCount, 1);
  });
}
