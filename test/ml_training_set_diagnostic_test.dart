// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/models/ml_feature_vector.dart';
import 'package:threatguard/core/services/logistic_regression_classifier.dart';
import 'package:threatguard/core/services/ml_feature_encoder.dart';
import 'package:threatguard/core/services/ml_training_dataset.dart';

void main() {
  test('diagnoses logistic regression on the full training dataset', () {
    const dataset = MlTrainingDataset();
    const encoder = MlFeatureEncoder();

    final examples = dataset.build();

    final featureVectors = examples
        .map((example) => encoder.encode(example.features))
        .toList();

    final classifier = LogisticRegressionClassifier.train(
      examples: examples,
      featureVectors: featureVectors,
      epochs: 1000,
      learningRate: 0.05,
      l2Penalty: 0.001,
    );

    var correct = 0;

    final correctByClass = <MlThreatType, int>{
      for (final type in MlThreatType.values) type: 0,
    };

    final totalByClass = <MlThreatType, int>{
      for (final type in MlThreatType.values) type: 0,
    };

    print('');
    print('===== ML TRAINING-SET DIAGNOSTIC =====');
    print('Training examples: ${examples.length}');
    print('');
    print(
      'IMPORTANT: This evaluates the model on the same cases used for training.',
    );
    print('It measures dataset fit, NOT generalization to unseen messages.');
    print('');

    for (var i = 0; i < examples.length; i++) {
      final example = examples[i];

      final prediction = classifier.predict(featureVectors[i]);

      totalByClass[example.label] = totalByClass[example.label]! + 1;

      if (prediction.type == example.label) {
        correct++;
        correctByClass[example.label] = correctByClass[example.label]! + 1;
      }

      print(
        '${example.features.caseId}: '
        'expected=${example.label.name}, '
        'predicted=${prediction.type.name}, '
        'confidence=${prediction.confidence.toStringAsFixed(4)}',
      );
    }

    final accuracy = correct / examples.length * 100;

    print('');
    print('----- SUMMARY -----');
    print('Correct: $correct/${examples.length}');
    print('Training-set accuracy: ${accuracy.toStringAsFixed(1)}%');
    print('');

    print('Per-class fit:');

    for (final type in MlThreatType.values) {
      final classCorrect = correctByClass[type]!;
      final classTotal = totalByClass[type]!;
      final classAccuracy = classCorrect / classTotal * 100;

      print(
        '  ${type.name}: '
        '$classCorrect/$classTotal '
        '(${classAccuracy.toStringAsFixed(1)}%)',
      );
    }

    print('====================');
    print('');

    expect(correct, greaterThanOrEqualTo(0));
    expect(correct, lessThanOrEqualTo(examples.length));
  });
}
