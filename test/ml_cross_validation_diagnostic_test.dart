// ignore_for_file: avoid_print

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/models/ml_feature_vector.dart';
import 'package:threatguard/core/models/ml_training_example.dart';
import 'package:threatguard/core/services/logistic_regression_classifier.dart';
import 'package:threatguard/core/services/ml_feature_encoder.dart';
import 'package:threatguard/core/services/ml_training_dataset.dart';

void main() {
  test(
    'evaluates ML model with deterministic 5-fold stratified cross-validation',
    () {
      const dataset = MlTrainingDataset();
      const encoder = MlFeatureEncoder();

      final examples = dataset.build();

      const foldCount = 5;

      final folds = _createStratifiedFolds(
        examples: examples,
        foldCount: foldCount,
      );

      var totalCorrect = 0;
      var totalTestCases = 0;

      print('');
      print('===== ML 5-FOLD CROSS-VALIDATION =====');
      print('Total examples: ${examples.length}');
      print('Number of folds: $foldCount');
      print('');
      print('Each case is used for testing exactly once.');
      print(
        'This is a robustness/generalization diagnostic, not a production model change.',
      );
      print('');

      for (var foldIndex = 0; foldIndex < foldCount; foldIndex++) {
        final testing = folds[foldIndex];

        final training = <MlTrainingExample>[];

        for (var otherFold = 0; otherFold < foldCount; otherFold++) {
          if (otherFold != foldIndex) {
            training.addAll(folds[otherFold]);
          }
        }

        final trainingVectors = training
            .map((example) => encoder.encode(example.features))
            .toList();

        final testingVectors = testing
            .map((example) => encoder.encode(example.features))
            .toList();

        final classifier = LogisticRegressionClassifier.train(
          examples: training,
          featureVectors: trainingVectors,
          epochs: 1000,
          learningRate: 0.05,
          l2Penalty: 0.001,
        );

        var foldCorrect = 0;

        for (var i = 0; i < testing.length; i++) {
          final prediction = classifier.predict(testingVectors[i]);

          if (prediction.type == testing[i].label) {
            foldCorrect++;
          }
        }

        final foldAccuracy = foldCorrect / testing.length * 100;

        totalCorrect += foldCorrect;
        totalTestCases += testing.length;

        print(
          'Fold ${foldIndex + 1}: '
          'training=${training.length}, '
          'testing=${testing.length}, '
          'correct=$foldCorrect/${testing.length}, '
          'accuracy=${foldAccuracy.toStringAsFixed(1)}%',
        );
      }

      final overallAccuracy = totalCorrect / totalTestCases * 100;

      print('');
      print('----- SUMMARY -----');
      print('Total held-out predictions: $totalTestCases');
      print('Total correct: $totalCorrect');
      print(
        '5-fold cross-validation accuracy: '
        '${overallAccuracy.toStringAsFixed(1)}%',
      );
      print('');
      print(
        'Interpretation: every case was evaluated by a model that was not '
        'trained on that case.',
      );
      print('==============================');
      print('');

      expect(totalTestCases, examples.length);
      expect(totalCorrect, greaterThanOrEqualTo(0));
      expect(totalCorrect, lessThanOrEqualTo(totalTestCases));
    },
  );
}

List<List<MlTrainingExample>> _createStratifiedFolds({
  required List<MlTrainingExample> examples,
  required int foldCount,
}) {
  final groups = <MlThreatType, List<MlTrainingExample>>{
    for (final type in MlThreatType.values) type: [],
  };

  for (final example in examples) {
    groups[example.label]!.add(example);
  }

  final folds = List.generate(foldCount, (_) => <MlTrainingExample>[]);

  var classIndex = 0;

  for (final group in groups.values) {
    final shuffled = List<MlTrainingExample>.from(group);

    _deterministicShuffle(shuffled, seed: 20260929 + classIndex * 997);

    for (var i = 0; i < shuffled.length; i++) {
      folds[i % foldCount].add(shuffled[i]);
    }

    classIndex++;
  }

  return folds;
}

void _deterministicShuffle(List<MlTrainingExample> items, {required int seed}) {
  final random = math.Random(seed);

  for (var i = items.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);

    final temporary = items[i];
    items[i] = items[j];
    items[j] = temporary;
  }
}
