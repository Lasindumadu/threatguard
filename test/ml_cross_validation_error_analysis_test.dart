// ignore_for_file: avoid_print

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/models/ml_feature_vector.dart';
import 'package:threatguard/core/models/ml_training_example.dart';
import 'package:threatguard/core/services/logistic_regression_classifier.dart';
import 'package:threatguard/core/services/ml_feature_encoder.dart';
import 'package:threatguard/core/services/ml_training_dataset.dart';

void main() {
  test('analyzes errors across deterministic 5-fold cross-validation', () {
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

    final errors = <_ClassificationError>[];

    print('');
    print('===== ML 5-FOLD ERROR ANALYSIS =====');
    print('Total examples: ${examples.length}');
    print('Number of folds: $foldCount');
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

      for (var i = 0; i < testing.length; i++) {
        final example = testing[i];

        final prediction = classifier.predict(testingVectors[i]);

        totalTestCases++;

        if (prediction.type == example.label) {
          totalCorrect++;
          continue;
        }

        errors.add(
          _ClassificationError(
            fold: foldIndex + 1,
            caseId: example.features.caseId,
            expected: example.label,
            predicted: prediction.type,
            confidence: prediction.confidence,
            features: example.features,
          ),
        );
      }
    }

    print('----- MISCLASSIFIED CASES -----');
    print('');

    if (errors.isEmpty) {
      print('No misclassified cases.');
    } else {
      for (final error in errors) {
        print('Fold ${error.fold}: ${error.caseId}');
        print('  expected:   ${error.expected.name}');
        print('  predicted:  ${error.predicted.name}');
        print('  confidence: ${error.confidence.toStringAsFixed(4)}');

        print(
          '  features: '
          'length=${error.features.messageLength}, '
          'words=${error.features.wordCount}, '
          'urls=${error.features.urlCount}',
        );

        print(
          '  signals: '
          'urgency=${error.features.hasUrgency}, '
          'accountSecurity=${error.features.hasAccountSecurity}, '
          'credential=${error.features.hasCredential}, '
          'financial=${error.features.hasFinancial}, '
          'prizeReward=${error.features.hasPrizeReward}, '
          'secrecy=${error.features.hasSecrecy}, '
          'authority=${error.features.hasAuthority}, '
          'promotion=${error.features.hasPromotion}',
        );

        print(
          '  url: '
          'hasUrl=${error.features.hasUrl}, '
          'suspicious=${error.features.hasSuspiciousUrl}, '
          'ip=${error.features.hasIpUrl}, '
          'punycode=${error.features.hasPunycodeUrl}, '
          'shortener=${error.features.hasShortenerUrl}',
        );

        print(
          '  context: '
          'accountVerification=${error.features.hasAccountVerification}, '
          'identityVerification=${error.features.hasIdentityVerification}, '
          'credentialRequest=${error.features.hasCredentialRequest}, '
          'strongCredentialRequest=${error.features.hasStrongCredentialRequest}',
        );

        print(
          '  interactions: '
          'prize+financial=${error.features.hasPrizeFinancialCombination}, '
          'account+credential=${error.features.hasAccountCredentialCombination}, '
          'authority+credential=${error.features.hasAuthorityCredentialCombination}, '
          'urgency+credential=${error.features.hasUrgencyCredentialCombination}',
        );

        print('');
      }
    }

    print('----- ERROR PATTERN SUMMARY -----');

    final confusionCounts = <String, int>{};

    for (final error in errors) {
      final key = '${error.expected.name} -> ${error.predicted.name}';

      confusionCounts[key] = (confusionCounts[key] ?? 0) + 1;
    }

    if (confusionCounts.isEmpty) {
      print('No classification errors.');
    } else {
      for (final entry in confusionCounts.entries) {
        print('${entry.key}: ${entry.value}');
      }
    }

    final accuracy = totalCorrect / totalTestCases * 100;

    print('');
    print('----- SUMMARY -----');
    print('Correct: $totalCorrect/$totalTestCases');
    print(
      'Cross-validation accuracy: '
      '${accuracy.toStringAsFixed(1)}%',
    );
    print('Misclassified: ${errors.length}');
    print('==============================');
    print('');

    expect(totalTestCases, examples.length);
    expect(errors.length, totalTestCases - totalCorrect);
  });
}

class _ClassificationError {
  final int fold;
  final String caseId;
  final MlThreatType expected;
  final MlThreatType predicted;
  final double confidence;
  final MlFeatureVector features;

  const _ClassificationError({
    required this.fold,
    required this.caseId,
    required this.expected,
    required this.predicted,
    required this.confidence,
    required this.features,
  });
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
