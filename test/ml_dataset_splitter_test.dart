import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/models/ml_feature_vector.dart';
import 'package:threatguard/core/services/ml_dataset_splitter.dart';
import 'package:threatguard/core/services/ml_training_dataset.dart';

void main() {
  test('creates training and testing sets with all five classes', () {
    const dataset = MlTrainingDataset();
    const splitter = MlDatasetSplitter();

    final examples = dataset.build();
    final split = splitter.split(examples);

    expect(split.training.length + split.testing.length, examples.length);

    expect(split.training.length, 70);
    expect(split.testing.length, 35);

    final trainingLabels = split.training
        .map((example) => example.label)
        .toSet();

    final testingLabels = split.testing.map((example) => example.label).toSet();

    expect(trainingLabels, containsAll(MlThreatType.values));
    expect(testingLabels, containsAll(MlThreatType.values));
  });

  test('does not reuse the same case in both sets', () {
    const dataset = MlTrainingDataset();
    const splitter = MlDatasetSplitter();

    final split = splitter.split(dataset.build());

    final trainingIds = split.training
        .map((example) => example.features.caseId)
        .toSet();

    final testingIds = split.testing
        .map((example) => example.features.caseId)
        .toSet();

    expect(trainingIds.intersection(testingIds), isEmpty);
  });

  test('seeded shuffled split is reproducible', () {
    const dataset = MlTrainingDataset();
    const splitter = MlDatasetSplitter();

    final examples = dataset.build();

    final first = splitter.splitShuffled(examples, seed: 42);

    final second = splitter.splitShuffled(examples, seed: 42);

    final firstTrainingIds = first.training
        .map((example) => example.features.caseId)
        .toList();

    final secondTrainingIds = second.training
        .map((example) => example.features.caseId)
        .toList();

    final firstTestingIds = first.testing
        .map((example) => example.features.caseId)
        .toList();

    final secondTestingIds = second.testing
        .map((example) => example.features.caseId)
        .toList();

    expect(firstTrainingIds, equals(secondTrainingIds));
    expect(firstTestingIds, equals(secondTestingIds));
  });

  test('seeded shuffled split preserves size and class coverage', () {
    const dataset = MlTrainingDataset();
    const splitter = MlDatasetSplitter();

    final split = splitter.splitShuffled(dataset.build(), seed: 42);

    expect(split.training.length, 70);
    expect(split.testing.length, 35);

    final trainingLabels = split.training
        .map((example) => example.label)
        .toSet();

    final testingLabels = split.testing.map((example) => example.label).toSet();

    expect(trainingLabels, containsAll(MlThreatType.values));
    expect(testingLabels, containsAll(MlThreatType.values));

    final trainingIds = split.training
        .map((example) => example.features.caseId)
        .toSet();

    final testingIds = split.testing
        .map((example) => example.features.caseId)
        .toSet();

    expect(trainingIds.intersection(testingIds), isEmpty);
  });

  test('different seeds can produce different splits', () {
    const dataset = MlTrainingDataset();
    const splitter = MlDatasetSplitter();

    final first = splitter.splitShuffled(dataset.build(), seed: 42);

    final second = splitter.splitShuffled(dataset.build(), seed: 99);

    final firstTestingIds = first.testing
        .map((example) => example.features.caseId)
        .toList();

    final secondTestingIds = second.testing
        .map((example) => example.features.caseId)
        .toList();

    expect(firstTestingIds, isNot(equals(secondTestingIds)));
  });
}
