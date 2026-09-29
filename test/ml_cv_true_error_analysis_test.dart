// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/ml_feature_vector.dart';
import 'package:threatguard/core/models/ml_training_example.dart';
import 'package:threatguard/core/services/evaluation_dataset.dart';
import 'package:threatguard/core/services/logistic_regression_classifier.dart';
import 'package:threatguard/core/services/ml_feature_encoder.dart';
import 'package:threatguard/core/services/ml_training_dataset.dart';

import 'dart:math' as math;

void main() {
  test('reproduces and analyzes true 5-fold CV errors', () {
    final dataset = const MlTrainingDataset().build();
    final encoder = const MlFeatureEncoder();

    final messageById = <String, String>{
      for (final evaluationCase in EvaluationDataset.cases)
        evaluationCase.id: evaluationCase.message,
    };

    final folds = _buildStratifiedFolds(dataset, foldCount: 5);

    var totalCorrect = 0;
    var totalTestCases = 0;
    final errors = <_CvError>[];

    print('');
    print('=' * 70);
    print('THREATGUARD V0.6 — TRUE 5-FOLD CV ERROR ANALYSIS');
    print('=' * 70);

    for (var foldIndex = 0; foldIndex < folds.length; foldIndex++) {
      final testExamples = folds[foldIndex];

      final trainingExamples = <MlTrainingExample>[];

      for (
        var otherFoldIndex = 0;
        otherFoldIndex < folds.length;
        otherFoldIndex++
      ) {
        if (otherFoldIndex == foldIndex) {
          continue;
        }

        trainingExamples.addAll(folds[otherFoldIndex]);
      }

      final trainingVectors = trainingExamples
          .map((example) => encoder.encode(example.features))
          .toList();

      final classifier = LogisticRegressionClassifier.train(
        examples: trainingExamples,
        featureVectors: trainingVectors,
      );

      print('');
      print('------------------------------------------------------------');
      print(
        'FOLD ${foldIndex + 1}: '
        '${trainingExamples.length} train / '
        '${testExamples.length} test',
      );
      print('------------------------------------------------------------');

      for (final example in testExamples) {
        final vector = encoder.encode(example.features);
        final prediction = classifier.predict(vector);

        totalTestCases++;

        if (prediction.type == example.label) {
          totalCorrect++;
          continue;
        }

        final message = messageById[example.features.caseId] ?? '';

        final error = _CvError(
          fold: foldIndex + 1,
          example: example,
          message: message,
          predicted: prediction.type,
          confidence: prediction.confidence,
        );

        errors.add(error);

        _printError(error);
      }
    }

    print('');
    print('=' * 70);
    print('CV SUMMARY');
    print('=' * 70);
    print('Correct: $totalCorrect/$totalTestCases');
    print(
      'Accuracy: '
      '${(totalCorrect / totalTestCases * 100).toStringAsFixed(1)}%',
    );
    print('Errors: ${errors.length}');

    for (final error in errors) {
      print(
        '  Fold ${error.fold}: '
        '${error.example.features.caseId} '
        '${_enumName(error.example.label)} -> '
        '${_enumName(error.predicted)} '
        '(${(error.confidence * 100).toStringAsFixed(2)}%)',
      );
    }

    print('=' * 70);

    expect(totalTestCases, 105);
  });
}

List<List<MlTrainingExample>> _buildStratifiedFolds(
  List<MlTrainingExample> examples, {
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

void _printError(_CvError error) {
  final f = error.example.features;

  print('');
  print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
  print('CV ERROR');
  print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');

  print('Fold:       ${error.fold}');
  print('Case:       ${f.caseId}');
  print('Expected:   ${_enumName(error.example.label)}');
  print('Predicted:  ${_enumName(error.predicted)}');
  print('Confidence: ${(error.confidence * 100).toStringAsFixed(2)}%');

  print('');
  print('Message:');
  print(error.message);

  print('');
  print('--- Numeric Features ---');
  print('messageLength: ${f.messageLength}');
  print('wordCount:     ${f.wordCount}');
  print('urlCount:      ${f.urlCount}');

  print('');
  print('--- Threat Signals ---');
  print('hasUrgency:              ${f.hasUrgency}');
  print('hasAccountSecurity:      ${f.hasAccountSecurity}');
  print('hasCredential:            ${f.hasCredential}');
  print('hasFinancial:             ${f.hasFinancial}');
  print('hasPrizeReward:           ${f.hasPrizeReward}');
  print('hasSecrecy:               ${f.hasSecrecy}');
  print('hasAuthority:             ${f.hasAuthority}');
  print('hasPromotion:             ${f.hasPromotion}');
  print('hasDeliveryContext:     ${f.hasDeliveryContext}');

  print('');
  print('--- URL Features ---');
  print('hasUrl:                   ${f.hasUrl}');
  print('hasSuspiciousUrl:         ${f.hasSuspiciousUrl}');
  print('hasIpUrl:                 ${f.hasIpUrl}');
  print('hasPunycodeUrl:           ${f.hasPunycodeUrl}');
  print('hasEmbeddedCredentialsUrl: ${f.hasEmbeddedCredentialsUrl}');
  print('hasNonStandardPortUrl:    ${f.hasNonStandardPortUrl}');
  print('hasExcessiveSubdomainsUrl: ${f.hasExcessiveSubdomainsUrl}');
  print('hasShortenerUrl:          ${f.hasShortenerUrl}');

  print('');
  print('--- Context Features ---');
  print('hasAccountVerification:   ${f.hasAccountVerification}');
  print('hasIdentityVerification:  ${f.hasIdentityVerification}');
  print('hasCredentialRequest:     ${f.hasCredentialRequest}');
  print(
    'hasStrongCredentialRequest: '
    '${f.hasStrongCredentialRequest}',
  );

  print('');
  print('--- Interaction Features ---');
  print(
    'hasPrizeFinancialCombination: '
    '${f.hasPrizeFinancialCombination}',
  );
  print(
    'hasAccountCredentialCombination: '
    '${f.hasAccountCredentialCombination}',
  );
  print(
    'hasAuthorityCredentialCombination: '
    '${f.hasAuthorityCredentialCombination}',
  );
  print(
    'hasUrgencyCredentialCombination: '
    '${f.hasUrgencyCredentialCombination}',
  );

  print('');
}

String _enumName(Object value) {
  return value.toString().split('.').last;
}

class _CvError {
  final int fold;
  final MlTrainingExample example;
  final String message;
  final MlThreatType predicted;
  final double confidence;

  const _CvError({
    required this.fold,
    required this.example,
    required this.message,
    required this.predicted,
    required this.confidence,
  });
}
