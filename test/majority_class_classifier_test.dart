// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/models/ml_feature_vector.dart';
import 'package:threatguard/core/services/majority_class_classifier.dart';
import 'package:threatguard/core/services/ml_feature_encoder.dart';
import 'package:threatguard/core/services/ml_training_dataset.dart';

void main() {
  test('majority classifier predicts the majority class', () {
    const classifier = MajorityClassClassifier(
      majorityType: MlThreatType.legitimate,
    );

    final prediction = classifier.predict(const []);

    expect(prediction.type, MlThreatType.legitimate);
    expect(prediction.confidence, 0.0);
  });

  test('measures majority-class baseline accuracy', () {
    const dataset = MlTrainingDataset();
    const encoder = MlFeatureEncoder();
    const classifier = MajorityClassClassifier(
      majorityType: MlThreatType.legitimate,
    );

    final examples = dataset.build();

    var correct = 0;

    for (final example in examples) {
      final features = encoder.encode(example.features);
      final prediction = classifier.predict(features);

      if (prediction.type == example.label) {
        correct++;
      }
    }

    final accuracy = correct / examples.length;

    print('');
    print('===== MAJORITY CLASS BASELINE =====');
    print('Total examples: ${examples.length}');
    print('Correct predictions: $correct');
    print('Accuracy: ${(accuracy * 100).toStringAsFixed(1)}%');
    print('===================================');
    print('');

    expect(correct, 24);
    expect(accuracy, closeTo(24 / 105, 0.001));
  });
}
