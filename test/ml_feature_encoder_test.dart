import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/services/ml_feature_encoder.dart';
import 'package:threatguard/core/services/ml_training_dataset.dart';

void main() {
  group('MlFeatureEncoder', () {
    const dataset = MlTrainingDataset();
    const encoder = MlFeatureEncoder();

    test('encodes a feature vector into 27 numeric values', () {
      final example = dataset.build().first;
      final encoded = encoder.encode(example.features);

      expect(encoded.length, 28);

      for (final value in encoded) {
        expect(value, isA<double>());
      }
    });

    test('preserves numeric message features', () {
      final example = dataset.build().first;
      final features = example.features;
      final encoded = encoder.encode(features);

      expect(encoded[0], features.messageLength.toDouble());
      expect(encoded[1], features.wordCount.toDouble());
      expect(encoded[2], features.urlCount.toDouble());
    });

    test('encodes boolean features as zero or one', () {
      final examples = dataset.build();

      for (final example in examples) {
        final encoded = encoder.encode(example.features);

        for (final value in encoded.skip(3)) {
          expect(value == 0.0 || value == 1.0, isTrue);
        }
      }
    });
  });
}
