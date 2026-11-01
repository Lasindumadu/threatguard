// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/services/evaluation_dataset.dart';
import 'package:threatguard/core/services/hybrid_threat_analyzer.dart';
import 'package:threatguard/core/services/logistic_regression_classifier.dart';
import 'package:threatguard/core/services/ml_dataset_splitter.dart';
import 'package:threatguard/core/services/ml_feature_encoder.dart';
import 'package:threatguard/core/services/ml_training_dataset.dart';

void main() {
  test('diagnoses hybrid routing on held-out cases', () {
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

    final hybridAnalyzer = HybridThreatAnalyzer(classifier: classifier);

    var mlUsedCount = 0;
    var ruleOnlyCount = 0;
    var finalCorrectCount = 0;
    var mlCorrectCount = 0;
    var ruleCorrectCount = 0;
    var mlChangedFinalTypeCount = 0;

    final mlUsedCases = <String>[];
    final ruleHandledCases = <String>[];
    final changedCases = <String>[];

    print('');
    print('===== HYBRID ROUTING DIAGNOSTIC =====');
    print('Training examples: ${split.training.length}');
    print('Held-out test examples: ${split.testing.length}');
    print('');

    for (final example in split.testing) {
      final evaluationCase = EvaluationDataset.cases.firstWhere(
        (item) => item.id == example.features.caseId,
      );

      final message = evaluationCase.message;

      final ruleAnalysis = hybridAnalyzer.threatAnalyzer.analyze(message);

      final mlFeatures = encoder.encode(example.features);
      final mlPrediction = classifier.predict(mlFeatures);

      final hybridAnalysis = hybridAnalyzer.analyze(message);

      final expectedType = example.label;

      final ruleType = ruleAnalysis.type;
      final mlType = mlPrediction.type;

      final finalType = hybridAnalysis.finalType;

      final ruleCorrect = ruleType.name == expectedType.name;

      final mlCorrect = mlType == expectedType;

      final finalCorrect = finalType.name == expectedType.name;

      if (ruleCorrect) {
        ruleCorrectCount++;
      }

      if (mlCorrect) {
        mlCorrectCount++;
      }

      if (finalCorrect) {
        finalCorrectCount++;
      }

      if (ruleType.name == 'legitimate') {
        mlUsedCount++;
        mlUsedCases.add(example.features.caseId);
      } else {
        ruleOnlyCount++;
        ruleHandledCases.add(example.features.caseId);
      }

      if (finalType != ruleType) {
        mlChangedFinalTypeCount++;
        changedCases.add(example.features.caseId);
      }

      print(
        '${example.features.caseId}: '
        'expected=${expectedType.name}, '
        'rule=${ruleType.name}, '
        'ml=${mlType.name}, '
        'final=${finalType.name}, '
        'confidence=${mlPrediction.confidence.toStringAsFixed(4)}',
      );
    }

    print('');
    print('----- SUMMARY -----');
    print('Rule-only handled: $ruleOnlyCount');
    print('ML-routed cases:   $mlUsedCount');
    print('Rule correct:      $ruleCorrectCount/${split.testing.length}');
    print('ML correct:        $mlCorrectCount/${split.testing.length}');
    print('Hybrid correct:    $finalCorrectCount/${split.testing.length}');
    print('ML changed final:  $mlChangedFinalTypeCount');
    print('');

    print('Cases routed to ML:');
    for (final caseId in mlUsedCases) {
      print('  - $caseId');
    }

    print('');
    print('Cases handled by rules:');
    for (final caseId in ruleHandledCases) {
      print('  - $caseId');
    }

    print('');
    print('Cases where ML changed the final classification:');

    if (changedCases.isEmpty) {
      print('  None');
    } else {
      for (final caseId in changedCases) {
        print('  - $caseId');
      }
    }

    print('===================');
    print('');

    expect(split.testing.length, 35);
    expect(ruleOnlyCount + mlUsedCount, 35);
    expect(finalCorrectCount, 35);
  });
}
