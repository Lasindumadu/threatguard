import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/ml_feature_vector.dart';
import 'package:threatguard/core/services/logistic_regression_classifier.dart';
import 'package:threatguard/core/services/ml_dataset_splitter.dart';
import 'package:threatguard/core/services/ml_feature_encoder.dart';
import 'package:threatguard/core/services/ml_training_dataset.dart';
import 'package:threatguard/core/services/model_evaluation.dart';

void main() {
  group('Honest held-out evaluation', () {
    const encoder = MlFeatureEncoder();
    const evaluator = ModelEvaluator();
    const splitter = MlDatasetSplitter();

    final allExamples = const MlTrainingDataset().build();

    test('the three-way split is stratified and non-empty', () {
      final split = splitter.splitThreeWay(allExamples, seed: 1337);

      expect(split.training, isNotEmpty);
      expect(split.dev, isNotEmpty);
      expect(split.testing, isNotEmpty);

      // No leakage: every case id appears in exactly one fold.
      final trainIds = split.training.map((e) => e.features.caseId).toSet();
      final devIds = split.dev.map((e) => e.features.caseId).toSet();
      final testIds = split.testing.map((e) => e.features.caseId).toSet();

      expect(trainIds.intersection(devIds), isEmpty);
      expect(trainIds.intersection(testIds), isEmpty);
      expect(devIds.intersection(testIds), isEmpty);

      expect(
        trainIds.length + devIds.length + testIds.length,
        allExamples.length,
      );

      // Every class must survive into the test fold, or per-class metrics lie.
      final testClasses = split.testing.map((e) => e.label).toSet();
      expect(
        testClasses.length,
        MlThreatType.values.length,
        reason: 'each class needs at least one held-out example',
      );
    });

    test('model generalises to unseen data and is reported honestly', () {
      final split = splitter.splitThreeWay(allExamples, seed: 1337);

      final classifier = LogisticRegressionClassifier.train(
        examples: split.training,
        featureVectors: split.training
            .map((e) => encoder.encode(e.features))
            .toList(),
      );

      final actual = <MlThreatType>[];
      final predicted = <MlThreatType>[];

      for (final example in split.testing) {
        actual.add(example.label);
        predicted.add(
          classifier.predict(encoder.encode(example.features)).type,
        );
      }

      final report = evaluator.evaluate(
        actual: actual,
        predicted: predicted,
        datasetLabel: 'held-out test',
      );

      // ignore: avoid_print
      print('\n${report.toReportString()}');

      // These are floor assertions, not targets. They fail loudly if a change
      // to the feature extractor or matcher causes a regression, which is the
      // point — the old diagnostic tests could never fail at all.
      expect(
        report.accuracy,
        greaterThan(0.60),
        reason: 'held-out accuracy collapsed',
      );

      expect(
        report.macroF1,
        greaterThan(0.50),
        reason: 'macro F1 collapsed — likely one class stopped being detected',
      );

      // For a consumer security product, false positives on legitimate
      // messages are worse than misses: they train users to ignore warnings.
      expect(
        report.falsePositiveRate,
        lessThan(0.25),
        reason: 'too many legitimate messages flagged as threats',
      );

      // The threat classes must do most of the work.
      expect(report.perClass[MlThreatType.phishing]!.recall, greaterThan(0.5));
      expect(report.perClass[MlThreatType.scam]!.recall, greaterThan(0.5));

      // A report is useless if every support is zero.
      final totalSupport = report.perClass.values.fold<int>(
        0,
        (acc, m) => acc + m.support,
      );
      expect(totalSupport, report.total);
    });

    test('training-set accuracy is not the same as held-out accuracy', () {
      final split = splitter.splitThreeWay(allExamples, seed: 1337);

      final classifier = LogisticRegressionClassifier.train(
        examples: split.training,
        featureVectors: split.training
            .map((e) => encoder.encode(e.features))
            .toList(),
      );

      MlThreatType predict(MlFeatureVector f) =>
          classifier.predict(encoder.encode(f)).type;

      final trainReport = evaluator.evaluate(
        actual: split.training.map((e) => e.label).toList(),
        predicted: split.training.map((e) => predict(e.features)).toList(),
        datasetLabel: 'train',
      );

      final testReport = evaluator.evaluate(
        actual: split.testing.map((e) => e.label).toList(),
        predicted: split.testing.map((e) => predict(e.features)).toList(),
        datasetLabel: 'test',
      );

      // Training accuracy should be at least as good as held-out accuracy.
      // If this ever inverts, the split is leaking.
      expect(trainReport.accuracy, greaterThanOrEqualTo(testReport.accuracy));
    });
  });

  group('ModelEvaluator metrics', () {
    const evaluator = ModelEvaluator();

    test('computes a correct confusion matrix and F1', () {
      final report = evaluator.evaluate(
        actual: [
          MlThreatType.phishing,
          MlThreatType.phishing,
          MlThreatType.legitimate,
          MlThreatType.spam,
        ],
        predicted: [
          MlThreatType.phishing,
          MlThreatType.scam,
          MlThreatType.legitimate,
          MlThreatType.spam,
        ],
      );

      expect(report.total, 4);
      expect(report.correct, 3);
      expect(report.accuracy, closeTo(0.75, 1e-9));

      final phishing = report.perClass[MlThreatType.phishing]!;
      expect(phishing.truePositives, 1);
      expect(phishing.falseNegatives, 1);
      expect(phishing.recall, closeTo(0.5, 1e-9));
      expect(phishing.precision, closeTo(1.0, 1e-9));
    });

    test(
      'false-positive rate counts legitimate messages flagged as threats',
      () {
        final report = evaluator.evaluate(
          actual: [
            MlThreatType.legitimate,
            MlThreatType.legitimate,
            MlThreatType.legitimate,
            MlThreatType.legitimate,
          ],
          predicted: [
            MlThreatType.legitimate,
            MlThreatType.legitimate,
            MlThreatType.legitimate,
            MlThreatType.phishing,
          ],
        );

        // 1 of 4 legitimate messages was wrongly flagged.
        expect(report.falsePositiveRate, closeTo(0.25, 1e-9));
        expect(report.threatPrecision, 0.0);
      },
    );
  });
}
