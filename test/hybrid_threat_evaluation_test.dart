// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/models/ml_feature_vector.dart';
import 'package:threatguard/core/models/threat_analysis.dart';
import 'package:threatguard/core/services/evaluation_dataset.dart';
import 'package:threatguard/core/services/hybrid_threat_analyzer.dart';
import 'package:threatguard/core/services/logistic_regression_classifier.dart';
import 'package:threatguard/core/services/ml_dataset_splitter.dart';
import 'package:threatguard/core/services/ml_feature_encoder.dart';
import 'package:threatguard/core/services/ml_training_dataset.dart';

void main() {
  test('evaluates rule-only, ML-only, and hybrid on held-out cases', () {
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

    var ruleCorrect = 0;
    var mlCorrect = 0;
    var hybridCorrect = 0;

    final ruleConfusionMatrix = <ThreatType, Map<ThreatType, int>>{
      for (final actual in ThreatType.values)
        actual: {for (final predicted in ThreatType.values) predicted: 0},
    };

    final mlConfusionMatrix = <MlThreatType, Map<MlThreatType, int>>{
      for (final actual in MlThreatType.values)
        actual: {for (final predicted in MlThreatType.values) predicted: 0},
    };

    final hybridConfusionMatrix = <ThreatType, Map<ThreatType, int>>{
      for (final actual in ThreatType.values)
        actual: {for (final predicted in ThreatType.values) predicted: 0},
    };

    for (final example in split.testing) {
      final evaluationCase = EvaluationDataset.cases.firstWhere(
        (item) => item.id == example.features.caseId,
      );

      final message = evaluationCase.message;

      final ruleAnalysis = hybridAnalyzer.threatAnalyzer.analyze(message);

      final mlFeatures = encoder.encode(example.features);
      final mlPrediction = classifier.predict(mlFeatures);

      final hybridAnalysis = hybridAnalyzer.analyze(message);

      final expectedType = _toThreatType(example.label);

      ruleConfusionMatrix[expectedType]![ruleAnalysis.type] =
          ruleConfusionMatrix[expectedType]![ruleAnalysis.type]! + 1;

      mlConfusionMatrix[example.label]![mlPrediction.type] =
          mlConfusionMatrix[example.label]![mlPrediction.type]! + 1;

      hybridConfusionMatrix[expectedType]![hybridAnalysis.finalType] =
          hybridConfusionMatrix[expectedType]![hybridAnalysis.finalType]! + 1;

      if (ruleAnalysis.type == expectedType) {
        ruleCorrect++;
      }

      if (mlPrediction.type == example.label) {
        mlCorrect++;
      }

      if (hybridAnalysis.finalType == expectedType) {
        hybridCorrect++;
      }

      if (hybridAnalysis.finalType != expectedType) {
        print('');
        print('===== HYBRID ERROR =====');
        print('Case: ${example.features.caseId}');
        print('Expected: ${expectedType.name}');
        print('Rule: ${ruleAnalysis.type.name}');
        print('ML: ${mlPrediction.type.name}');
        print(
          'ML confidence: '
          '${mlPrediction.confidence.toStringAsFixed(4)}',
        );
        print('Hybrid: ${hybridAnalysis.finalType.name}');
        print('========================');
      }
    }

    final testCount = split.testing.length;

    final ruleAccuracy = ruleCorrect / testCount;
    final mlAccuracy = mlCorrect / testCount;
    final hybridAccuracy = hybridCorrect / testCount;

    print('');
    print('===== HYBRID THREAT EVALUATION =====');
    print('Training examples: ${split.training.length}');
    print('Held-out test examples: $testCount');
    print('');
    print(
      'Rule-only: '
      '$ruleCorrect/$testCount '
      '(${(ruleAccuracy * 100).toStringAsFixed(1)}%)',
    );
    print(
      'ML-only:   '
      '$mlCorrect/$testCount '
      '(${(mlAccuracy * 100).toStringAsFixed(1)}%)',
    );
    print(
      'Hybrid:    '
      '$hybridCorrect/$testCount '
      '(${(hybridAccuracy * 100).toStringAsFixed(1)}%)',
    );

    print('');
    print('Rule-only confusion matrix:');

    for (final actual in ThreatType.values) {
      final row = ruleConfusionMatrix[actual]!;

      print(
        '${actual.name}: '
        '${row.entries.map((entry) => '${entry.key.name}=${entry.value}').join(', ')}',
      );
    }

    print('');
    print('ML-only confusion matrix:');

    for (final actual in MlThreatType.values) {
      final row = mlConfusionMatrix[actual]!;

      print(
        '${actual.name}: '
        '${row.entries.map((entry) => '${entry.key.name}=${entry.value}').join(', ')}',
      );
    }

    print('');
    print('Hybrid confusion matrix:');

    for (final actual in ThreatType.values) {
      final row = hybridConfusionMatrix[actual]!;

      print(
        '${actual.name}: '
        '${row.entries.map((entry) => '${entry.key.name}=${entry.value}').join(', ')}',
      );
    }

    print('====================================');
    print('');

    expect(testCount, 35);

    expect(ruleAccuracy, greaterThanOrEqualTo(0.0));
    expect(ruleAccuracy, lessThanOrEqualTo(1.0));

    expect(mlAccuracy, greaterThanOrEqualTo(0.0));
    expect(mlAccuracy, lessThanOrEqualTo(1.0));

    expect(hybridAccuracy, greaterThanOrEqualTo(0.0));
    expect(hybridAccuracy, lessThanOrEqualTo(1.0));
  });
}

ThreatType _toThreatType(MlThreatType type) {
  switch (type) {
    case MlThreatType.legitimate:
      return ThreatType.legitimate;
    case MlThreatType.spam:
      return ThreatType.spam;
    case MlThreatType.phishing:
      return ThreatType.phishing;
    case MlThreatType.scam:
      return ThreatType.scam;
    case MlThreatType.socialEngineering:
      return ThreatType.socialEngineering;
  }
}
