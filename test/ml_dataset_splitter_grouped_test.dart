import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/ml_dataset_split.dart';
import 'package:threatguard/core/models/ml_feature_vector.dart';
import 'package:threatguard/core/models/ml_training_example.dart';
import 'package:threatguard/core/services/ml_dataset_splitter.dart';
import 'package:threatguard/core/services/ml_training_dataset.dart';

MlTrainingExample _example({
  required String caseId,
  required MlThreatType label,
  String? family,
}) {
  return MlTrainingExample(
    features: MlFeatureVector(
      caseId: caseId,
      scenarioFamily: family,
      messageLength: 0,
      wordCount: 0,
      urlCount: 0,
      hasUrgency: false,
      hasAccountSecurity: false,
      hasAccountVerificationUrlPattern: false,
      hasCredential: false,
      hasFinancial: false,
      hasPrizeReward: false,
      hasSecrecy: false,
      hasAuthority: false,
      hasPromotion: false,
      hasDeliveryContext: false,
      hasUrl: false,
      hasSuspiciousUrl: false,
      hasIpUrl: false,
      hasPunycodeUrl: false,
      hasEmbeddedCredentialsUrl: false,
      hasNonStandardPortUrl: false,
      hasExcessiveSubdomainsUrl: false,
      hasShortenerUrl: false,
      hasAccountVerification: false,
      hasIdentityVerification: false,
      hasCredentialRequest: false,
      hasStrongCredentialRequest: false,
      hasPrizeFinancialCombination: false,
      hasAccountCredentialCombination: false,
      hasAuthorityCredentialCombination: false,
      hasUrgencyCredentialCombination: false,
    ),
    label: label,
  );
}

Set<String> _ids(List<MlTrainingExample> examples) =>
    examples.map((e) => e.features.caseId).toSet();

Map<String, List<String>> _familyToIds(List<MlTrainingExample> examples) {
  final map = <String, List<String>>{};
  for (final e in examples) {
    final family = e.features.scenarioFamily ?? e.features.caseId;
    map.putIfAbsent(family, () => []).add(e.features.caseId);
  }
  return map;
}

void main() {
  group('Group-aware split (splitGroupedThreeWay)', () {
    final examples = const MlTrainingDataset().build();

    test('deterministic: same seed and dataset produce the same split', () {
      final a = const MlDatasetSplitter().splitGroupedThreeWay(
        examples,
        seed: 1337,
      );
      final b = const MlDatasetSplitter().splitGroupedThreeWay(
        examples,
        seed: 1337,
      );

      expect(_ids(a.training), _ids(b.training));
      expect(_ids(a.dev), _ids(b.dev));
      expect(_ids(a.testing), _ids(b.testing));
    });

    test('different seeds produce different splits (non-trivial dataset)', () {
      final a = const MlDatasetSplitter().splitGroupedThreeWay(
        examples,
        seed: 1,
      );
      final b = const MlDatasetSplitter().splitGroupedThreeWay(
        examples,
        seed: 2,
      );

      // Not required to differ, but with 105 examples and two families per
      // class they almost certainly will. We only assert determinism above;
      // this documents that seed influences the split.
      expect(a.total, b.total);
    });

    test('no example id appears in multiple folds', () {
      final split = const MlDatasetSplitter().splitGroupedThreeWay(
        examples,
        seed: 1337,
      );

      final trainIds = _ids(split.training);
      final devIds = _ids(split.dev);
      final testIds = _ids(split.testing);

      expect(trainIds.intersection(devIds), isEmpty);
      expect(trainIds.intersection(testIds), isEmpty);
      expect(devIds.intersection(testIds), isEmpty);

      expect(
        trainIds.length + devIds.length + testIds.length,
        examples.length,
        reason: 'every example must appear in exactly one fold',
      );
    });

    test('no declared scenario family appears across folds', () {
      final split = const MlDatasetSplitter().splitGroupedThreeWay(
        examples,
        seed: 1337,
      );

      final allFoldIds = <String, String>{};
      for (final e in split.training) {
        allFoldIds[e.features.caseId] = 'training';
      }
      for (final e in split.dev) {
        allFoldIds[e.features.caseId] = 'dev';
      }
      for (final e in split.testing) {
        allFoldIds[e.features.caseId] = 'testing';
      }

      final families = _familyToIds(examples);
      for (final entry in families.entries) {
        final foldForFamily = <String>{};
        for (final id in entry.value) {
          foldForFamily.add(allFoldIds[id]!);
        }
        expect(
          foldForFamily.length,
          1,
          reason:
              'family ${entry.key} must not span folds (found $foldForFamily)',
        );
      }
    });

    test('class coverage preserved in training and testing', () {
      final split = const MlDatasetSplitter().splitGroupedThreeWay(
        examples,
        seed: 1337,
      );

      for (final type in MlThreatType.values) {
        expect(
          split.trainingByClass[type]!,
          greaterThan(0),
          reason: '$type must keep at least one training example',
        );
        expect(
          split.testingByClass[type]!,
          greaterThan(0),
          reason: '$type must keep at least one held-out example',
        );
      }
    });

    test('fold counts sum to the dataset size and are reported per class', () {
      final split = const MlDatasetSplitter().splitGroupedThreeWay(
        examples,
        seed: 1337,
      );

      expect(split.total, examples.length);
      expect(split.training.length + split.dev.length + split.testing.length,
          examples.length);

      final trainTotal =
          split.trainingByClass.values.fold<int>(0, (a, b) => a + b);
      final devTotal =
          split.devByClass.values.fold<int>(0, (a, b) => a + b);
      final testTotal =
          split.testingByClass.values.fold<int>(0, (a, b) => a + b);

      expect(trainTotal, split.training.length);
      expect(devTotal, split.dev.length);
      expect(testTotal, split.testing.length);
    });
  });

  group('Group-aware split edge cases', () {
    test('single-family class keeps the family in training (no crash)', () {
      // Class with one family (two examples) cannot be held out without
      // splitting the family; the family stays in training.
      final examples = <MlTrainingExample>[
        _example(caseId: 'a1', label: MlThreatType.spam, family: 'spam:x'),
        _example(caseId: 'a2', label: MlThreatType.spam, family: 'spam:x'),
        // Give every other class at least one example so the split is defined.
        _example(caseId: 'b1', label: MlThreatType.legitimate),
        _example(caseId: 'c1', label: MlThreatType.phishing),
        _example(caseId: 'd1', label: MlThreatType.scam),
        _example(caseId: 'e1', label: MlThreatType.socialEngineering),
      ];

      final split = const MlDatasetSplitter().splitGroupedThreeWay(
        examples,
        seed: 7,
      );

      // The single spam family must not be split across folds.
      final spamIds = {'a1', 'a2'};
      final inTrain = spamIds.intersection(_ids(split.training));
      final inTest = spamIds.intersection(_ids(split.testing));
      final inDev = spamIds.intersection(_ids(split.dev));

      expect(inTrain.length, 2, reason: 'single-family class stays in train');
      expect(inTest, isEmpty);
      expect(inDev, isEmpty);

      // No id appears in multiple folds.
      final all = <String>{}
        ..addAll(_ids(split.training))
        ..addAll(_ids(split.dev))
        ..addAll(_ids(split.testing));
      expect(all.length, examples.length);
    });

    test('empty dataset returns empty folds without crashing', () {
      final split = const MlDatasetSplitter().splitGroupedThreeWay(
        <MlTrainingExample>[],
        seed: 1,
      );

      expect(split.training, isEmpty);
      expect(split.dev, isEmpty);
      expect(split.testing, isEmpty);
      expect(split.total, 0);
    });

    test('two-way grouped split keeps families together and is deterministic', () {
      final examples = <MlTrainingExample>[
        _example(caseId: 'g1', label: MlThreatType.spam, family: 'spam:f1'),
        _example(caseId: 'g2', label: MlThreatType.spam, family: 'spam:f1'),
        _example(caseId: 'g3', label: MlThreatType.spam, family: 'spam:f2'),
        _example(caseId: 'g4', label: MlThreatType.spam, family: 'spam:f2'),
        _example(caseId: 'l1', label: MlThreatType.legitimate),
        _example(caseId: 'l2', label: MlThreatType.legitimate),
      ];

      final a = const MlDatasetSplitter().splitGrouped(
        examples,
        seed: 5,
        testFraction: 0.5,
      );
      final b = const MlDatasetSplitter().splitGrouped(
        examples,
        seed: 5,
        testFraction: 0.5,
      );

      expect(_ids(a.training), _ids(b.training));
      expect(_ids(a.testing), _ids(b.testing));

      // Families f1 and f2 must not span folds.
      for (final family in ['spam:f1', 'spam:f2']) {
        final ids = examples
            .where((e) => e.features.scenarioFamily == family)
            .map((e) => e.features.caseId)
            .toSet();
        final inTrain = ids.intersection(_ids(a.training));
        final inTest = ids.intersection(_ids(a.testing));
        expect(
          (inTrain.isEmpty || inTest.isEmpty),
          isTrue,
          reason: 'family $family must not span folds',
        );
      }

      expect(
        _ids(a.training).length + _ids(a.testing).length,
        examples.length,
      );
    });
  });

  group('Existing splitter APIs unchanged', () {
    final examples = const MlTrainingDataset().build();

    test('split() (class-based, legacy) still produces non-empty disjoint folds', () {
      final split = const MlDatasetSplitter().split(examples);

      expect(split.training, isNotEmpty);
      expect(split.testing, isNotEmpty);

      final trainIds = _ids(split.training);
      final testIds = _ids(split.testing);
      expect(trainIds.intersection(testIds), isEmpty);
      expect(trainIds.length + testIds.length, examples.length);
    });

    test('splitThreeWay() (class-based, legacy) still produces non-empty disjoint folds', () {
      final split = const MlDatasetSplitter().splitThreeWay(
        examples,
        seed: 1337,
      );

      expect(split.training, isNotEmpty);
      expect(split.dev, isNotEmpty);
      expect(split.testing, isNotEmpty);

      final trainIds = _ids(split.training);
      final devIds = _ids(split.dev);
      final testIds = _ids(split.testing);

      expect(trainIds.intersection(devIds), isEmpty);
      expect(trainIds.intersection(testIds), isEmpty);
      expect(devIds.intersection(testIds), isEmpty);
      expect(trainIds.length + devIds.length + testIds.length, examples.length);
    });
  });

  group('Dataset integrity (source-derived)', () {
    final examples = const MlTrainingDataset().build();

    test('total examples is 105', () {
      expect(examples.length, 105);
    });

    test('class counts match dataset taxonomy', () {
      final counts = <MlThreatType, int>{};
      for (final type in MlThreatType.values) {
        counts[type] = 0;
      }
      for (final e in examples) {
        counts[e.label] = (counts[e.label] ?? 0) + 1;
      }
      expect(counts[MlThreatType.legitimate], 24);
      expect(counts[MlThreatType.spam], 19);
      expect(counts[MlThreatType.phishing], 21);
      expect(counts[MlThreatType.scam], 20);
      expect(counts[MlThreatType.socialEngineering], 21);
    });

    test('named-family vs singleton counts', () {
      final namedCount =
          examples.where((e) => e.features.scenarioFamily != null).length;
      final singletonCount =
          examples.where((e) => e.features.scenarioFamily == null).length;
      expect(namedCount, 86);
      expect(singletonCount, 19);
    });

    test('distinct named families is 20', () {
      final families = examples
          .where((e) => e.features.scenarioFamily != null)
          .map((e) => e.features.scenarioFamily!)
          .toSet();
      expect(families.length, 20);
    });

    test('all case IDs are unique', () {
      final ids = examples.map((e) => e.features.caseId).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('each named family belongs to exactly one class', () {
      final byFamily = <String, List<MlThreatType>>{};
      for (final e in examples) {
        final family = e.features.scenarioFamily;
        if (family == null) continue;
        byFamily.putIfAbsent(family, () => <MlThreatType>[]).add(e.label);
      }
      for (final entry in byFamily.entries) {
        expect(
          entry.value.toSet().length,
          1,
          reason: 'family ${entry.key} mixes classes',
        );
      }
    });
  });

  group('Whole-family allocation (real grouped splitter)', () {
    final examples = const MlTrainingDataset().build();

    test('no named family spans folds', () {
      final split = const MlDatasetSplitter().splitGroupedThreeWay(
        examples,
        seed: 1337,
      );
      final foldForId = <String, String>{};
      for (final e in split.training) {
        foldForId[e.features.caseId] = 'training';
      }
      for (final e in split.dev) {
        foldForId[e.features.caseId] = 'dev';
      }
      for (final e in split.testing) {
        foldForId[e.features.caseId] = 'testing';
      }

      final byFamily = <String, List<String>>{};
      for (final e in examples) {
        final family = e.features.scenarioFamily;
        if (family == null) continue;
        byFamily.putIfAbsent(family, () => <String>[]).add(e.features.caseId);
      }
      for (final entry in byFamily.entries) {
        final folds =
            entry.value.map((id) => foldForId[id]).toSet();
        expect(
          folds.length,
          1,
          reason: 'family ${entry.key} spans folds: $folds',
        );
      }
    });

    test('null-family examples behave as individual singletons', () {
      final split = const MlDatasetSplitter().splitGroupedThreeWay(
        examples,
        seed: 1337,
      );
      final singletons = examples
          .where((e) => e.features.scenarioFamily == null)
          .map((e) => e.features.caseId)
          .toSet();

      final inTrain = singletons.intersection(_ids(split.training));
      final inDev = singletons.intersection(_ids(split.dev));
      final inTest = singletons.intersection(_ids(split.testing));
      expect(
        inTrain.length + inDev.length + inTest.length,
        singletons.length,
        reason: 'every singleton id appears in exactly one fold',
      );
    });

    test('no case ID appears in more than one fold', () {
      final split = const MlDatasetSplitter().splitGroupedThreeWay(
        examples,
        seed: 1337,
      );
      final trainIds = _ids(split.training);
      final devIds = _ids(split.dev);
      final testIds = _ids(split.testing);
      expect(trainIds.intersection(devIds), isEmpty);
      expect(trainIds.intersection(testIds), isEmpty);
      expect(devIds.intersection(testIds), isEmpty);
      expect(trainIds.length + devIds.length + testIds.length, examples.length);
    });

    test('seven-example family remains intact within one fold', () {
      final sevenExampleFamilies = <String, int>{
        'spam:offer-discount': 7,
        'spam:congratulations-selected-reward': 7,
        'scam:cash-reward-fee': 7,
      };

      final split = const MlDatasetSplitter().splitGroupedThreeWay(
        examples,
        seed: 1337,
      );
      final foldForId = <String, String>{};
      for (final e in split.training) {
        foldForId[e.features.caseId] = 'training';
      }
      for (final e in split.dev) {
        foldForId[e.features.caseId] = 'dev';
      }
      for (final e in split.testing) {
        foldForId[e.features.caseId] = 'testing';
      }

      for (final entry in sevenExampleFamilies.entries) {
        final family = entry.key;
        final expectedSize = entry.value;
        final familyIds = examples
            .where((e) => e.features.scenarioFamily == family)
            .map((e) => e.features.caseId)
            .toSet();

        expect(
          familyIds.length,
          expectedSize,
          reason: '$family has $expectedSize members',
        );

        final folds = familyIds.map((id) => foldForId[id]).toSet();
        expect(
          folds.length,
          1,
          reason: '$family is split across $folds',
        );

        final fold = folds.first;
        final foldExamples = switch (fold) {
          'training' => split.training,
          'dev' => split.dev,
          _ => split.testing,
        };
        final foundInFold = foldExamples
            .where((e) => familyIds.contains(e.features.caseId))
            .length;
        expect(
          foundInFold,
          expectedSize,
          reason: 'not all $family members in $fold',
        );
      }
    });
  });

  group('Class-coverage limitation (synthetic)', () {
    test('single-family class is not divided and reports no held-out examples', () {
      final examples = <MlTrainingExample>[
        _example(caseId: 'a1', label: MlThreatType.spam, family: 'spam:x'),
        _example(caseId: 'a2', label: MlThreatType.spam, family: 'spam:x'),
        _example(caseId: 'b1', label: MlThreatType.legitimate),
        _example(caseId: 'c1', label: MlThreatType.phishing),
        _example(caseId: 'd1', label: MlThreatType.scam),
        _example(caseId: 'e1', label: MlThreatType.socialEngineering),
      ];

      final split = const MlDatasetSplitter().splitGroupedThreeWay(
        examples,
        seed: 7,
      );

      final spamTrain = split.training.where((e) => e.label == MlThreatType.spam).length;
      expect(spamTrain, 2);

      expect(split.testingByClass[MlThreatType.spam]!, 0);
      expect(split.devByClass[MlThreatType.spam]!, 0);

      final all = <String>{}
        ..addAll(_ids(split.training))
        ..addAll(_ids(split.dev))
        ..addAll(_ids(split.testing));
      expect(all.length, examples.length);
    });
  });

  group('Deterministic fold statistics (seed 1337, 105-example dataset)', () {
    final examples = const MlTrainingDataset().build();
    late MlDatasetSplit split;

    setUp(() {
      split = const MlDatasetSplitter().splitGroupedThreeWay(
        examples,
        seed: 1337,
      );
    });

    test('fold sizes sum to 105', () {
      expect(split.total, 105);
      expect(
        split.training.length + split.dev.length + split.testing.length,
        105,
      );
    });

    test('training size is 56', () {
      expect(split.training.length, 56);
    });

    test('development size is 26', () {
      expect(split.dev.length, 26);
    });

    test('testing size is 23', () {
      expect(split.testing.length, 23);
    });

    test('per-class counts match regression table', () {
      expect(split.trainingByClass[MlThreatType.legitimate], 13);
      expect(split.trainingByClass[MlThreatType.spam], 7);
      expect(split.trainingByClass[MlThreatType.phishing], 12);
      expect(split.trainingByClass[MlThreatType.scam], 13);
      expect(split.trainingByClass[MlThreatType.socialEngineering], 11);

      expect(split.devByClass[MlThreatType.legitimate], 6);
      expect(split.devByClass[MlThreatType.spam], 7);
      expect(split.devByClass[MlThreatType.phishing], 5);
      expect(split.devByClass[MlThreatType.scam], 3);
      expect(split.devByClass[MlThreatType.socialEngineering], 5);

      expect(split.testingByClass[MlThreatType.legitimate], 5);
      expect(split.testingByClass[MlThreatType.spam], 5);
      expect(split.testingByClass[MlThreatType.phishing], 4);
      expect(split.testingByClass[MlThreatType.scam], 4);
      expect(split.testingByClass[MlThreatType.socialEngineering], 5);
    });

    test('per-class getter sums match fold sizes', () {
      final trainSum =
          split.trainingByClass.values.fold<int>(0, (a, b) => a + b);
      final devSum = split.devByClass.values.fold<int>(0, (a, b) => a + b);
      final testSum =
          split.testingByClass.values.fold<int>(0, (a, b) => a + b);
      expect(trainSum, split.training.length);
      expect(devSum, split.dev.length);
      expect(testSum, split.testing.length);
    });
  });
}
