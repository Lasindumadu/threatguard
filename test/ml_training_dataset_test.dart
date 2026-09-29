import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/models/ml_feature_vector.dart';
import 'package:threatguard/core/services/ml_training_dataset.dart';

void main() {
  group('MlTrainingDataset', () {
    const dataset = MlTrainingDataset();

    test('builds all V0.6 evaluation cases', () {
      final examples = dataset.build();

      expect(examples.length, 105);

      for (final example in examples) {
        expect(example.features.caseId, isNotEmpty);
        expect(example.features.messageLength, greaterThan(0));
        expect(example.features.wordCount, greaterThan(0));
      }
    });

    test('contains all five threat classes', () {
      final examples = dataset.build();

      final labels = examples.map((example) => example.label).toSet();

      expect(
        labels,
        containsAll(<MlThreatType>[
          MlThreatType.legitimate,
          MlThreatType.spam,
          MlThreatType.phishing,
          MlThreatType.scam,
          MlThreatType.socialEngineering,
        ]),
      );
    });

    test('preserves case IDs from the evaluation dataset', () {
      final examples = dataset.build();

      final ids = examples.map((example) => example.features.caseId).toSet();

      expect(ids.length, 105);
    });
  });
}
