import '../models/ml_dataset_split.dart';
import '../models/ml_training_example.dart';
import '../models/ml_feature_vector.dart';

class MlDatasetSplitter {
  const MlDatasetSplitter();

  MlDatasetSplit split(List<MlTrainingExample> examples) {
    return _splitByGroups(examplesByClass: _groupByClass(examples));
  }

  MlDatasetSplit splitShuffled(
    List<MlTrainingExample> examples, {
    required int seed,
  }) {
    final groups = _groupByClass(examples);
    final shuffledGroups = <MlThreatType, List<MlTrainingExample>>{};

    for (final entry in groups.entries) {
      final group = List<MlTrainingExample>.from(entry.value);
      _shuffle(group, seed + entry.key.index);
      shuffledGroups[entry.key] = group;
    }

    return _splitByGroups(examplesByClass: shuffledGroups);
  }

  /// Three-way stratified split: train / dev / test.
  ///
  /// A separate dev set exists so hyper-parameters can be tuned without
  /// touching the test set, which is what makes the final reported number
  /// honest. Every split keeps at least one example of every class, so no
  /// per-class metric is ever undefined.
  ///
  /// This is the legacy class-based split: it does not respect scenario
  /// families, so near-duplicate templates can appear in both training and
  /// held-out folds. Use [splitGroupedThreeWay] for group-aware evaluation.
  MlDatasetSplit splitThreeWay(
    List<MlTrainingExample> examples, {
    required int seed,
    double devFraction = 0.15,
    double testFraction = 0.20,
  }) {
    final groups = _groupByClass(examples);

    final training = <MlTrainingExample>[];
    final dev = <MlTrainingExample>[];
    final testing = <MlTrainingExample>[];

    for (final entry in groups.entries) {
      final group = List<MlTrainingExample>.from(entry.value)
        ..sort((a, b) => a.features.caseId.compareTo(b.features.caseId));
      _shuffle(group, seed + entry.key.index);

      final n = group.length;
      if (n == 0) continue;

      // Guarantee at least one test example whenever the class has >= 3 items,
      // and never let train fall below one example.
      var testCount = (n * testFraction).round();
      if (n >= 3 && testCount == 0) testCount = 1;
      if (n - testCount < 1) testCount = n - 1;

      var devCount = (n * devFraction).round();
      if (n >= 5 && devCount == 0) devCount = 1;
      if (n - testCount - devCount < 1) devCount = n - testCount - 1;
      if (devCount < 0) devCount = 0;

      testing.addAll(group.take(testCount));
      dev.addAll(group.skip(testCount).take(devCount));
      training.addAll(group.skip(testCount + devCount));
    }

    return MlDatasetSplit(training: training, dev: dev, testing: testing);
  }

  /// Group-aware three-way split: train / dev / test.
  ///
  /// All examples sharing a [scenarioFamily] are kept in the same fold, so
  /// near-duplicate scenario templates cannot leak from training into held-out
  /// evaluation. Families are atomic: a family is never divided across folds.
  ///
  /// The split is deterministic for a fixed [seed] and dataset: examples are
  /// ordered by case id before shuffling, and each class is shuffled with a
  /// class-derived seed (`seed + type.index`).
  ///
  /// Fold sizes are reported exactly via the returned [MlDatasetSplit] (and its
  /// `trainingByClass`/`devByClass`/`testingByClass` getters); they are not
  /// assumed to be any fixed ratio such as 70/14/21.
  ///
  /// Class coverage is preserved in training wherever the dataset permits: at
  /// least one family of every class is left for training. A class consisting of
  /// a single family cannot be held out without splitting that family; in that
  /// case the family stays in training and the class receives no held-out
  /// examples (a dataset limitation, not a bug).
  MlDatasetSplit splitGroupedThreeWay(
    List<MlTrainingExample> examples, {
    required int seed,
    double devFraction = 0.15,
    double testFraction = 0.20,
  }) {
    final byFamily = _groupByFamily(examples);

    final familiesByClass = <MlThreatType, List<List<MlTrainingExample>>>{};
    for (final type in MlThreatType.values) {
      familiesByClass[type] = [];
    }
    for (final family in byFamily.values) {
      familiesByClass[family.first.label]!.add(family);
    }

    final training = <MlTrainingExample>[];
    final dev = <MlTrainingExample>[];
    final testing = <MlTrainingExample>[];

    for (final type in MlThreatType.values) {
      final families = List<List<MlTrainingExample>>.from(
        familiesByClass[type]!,
      );
      // Deterministic pre-shuffle order, then a reproducible shuffle.
      families.sort(
        (a, b) => a.first.features.caseId.compareTo(b.first.features.caseId),
      );
      _shuffle(families, seed + type.index);

      final total = families.fold<int>(
        0,
        (sum, family) => sum + family.length,
      );

      _allocateFamilies(
        families: families,
        total: total,
        devFraction: devFraction,
        testFraction: testFraction,
        training: training,
        dev: dev,
        testing: testing,
      );
    }

    return MlDatasetSplit(training: training, dev: dev, testing: testing);
  }

  /// Group-aware two-way split: train / testing.
  ///
  /// See [splitGroupedThreeWay] for the grouping and determinism guarantees.
  MlDatasetSplit splitGrouped(
    List<MlTrainingExample> examples, {
    required int seed,
    double testFraction = 0.33,
  }) {
    final byFamily = _groupByFamily(examples);

    final familiesByClass = <MlThreatType, List<List<MlTrainingExample>>>{};
    for (final type in MlThreatType.values) {
      familiesByClass[type] = [];
    }
    for (final family in byFamily.values) {
      familiesByClass[family.first.label]!.add(family);
    }

    final training = <MlTrainingExample>[];
    final testing = <MlTrainingExample>[];

    for (final type in MlThreatType.values) {
      final families = List<List<MlTrainingExample>>.from(
        familiesByClass[type]!,
      );
      families.sort(
        (a, b) => a.first.features.caseId.compareTo(b.first.features.caseId),
      );
      _shuffle(families, seed + type.index);

      final total = families.fold<int>(
        0,
        (sum, family) => sum + family.length,
      );

      _allocateTwoWay(
        families: families,
        total: total,
        testFraction: testFraction,
        training: training,
        testing: testing,
      );
    }

    return MlDatasetSplit(training: training, testing: testing);
  }

  Map<MlThreatType, List<MlTrainingExample>> _groupByClass(
    List<MlTrainingExample> examples,
  ) {
    final groups = <MlThreatType, List<MlTrainingExample>>{
      for (final type in MlThreatType.values) type: [],
    };

    for (final example in examples) {
      groups[example.label]!.add(example);
    }

    return groups;
  }

  /// Groups examples by scenario family. A null family means the example is a
  /// unique singleton family keyed by its case id.
  Map<String, List<MlTrainingExample>> _groupByFamily(
    List<MlTrainingExample> examples,
  ) {
    final groups = <String, List<MlTrainingExample>>{};

    for (final example in examples) {
      final family = example.features.scenarioFamily ?? example.features.caseId;
      groups.putIfAbsent(family, () => <MlTrainingExample>[]).add(example);
    }

    return groups;
  }

  MlDatasetSplit _splitByGroups({
    required Map<MlThreatType, List<MlTrainingExample>> examplesByClass,
  }) {
    final training = <MlTrainingExample>[];
    final testing = <MlTrainingExample>[];

    for (final group in examplesByClass.values) {
      var testCount = _testCount(group.length);

      // Never leave a class out of the test set entirely when it has enough
      // examples to spare one, and never empty the training set.
      if (group.length >= 3 && testCount == 0) testCount = 1;
      if (group.length - testCount < 1) testCount = group.length - 1;
      if (testCount < 0) testCount = 0;

      testing.addAll(group.take(testCount));
      training.addAll(group.skip(testCount));
    }

    return MlDatasetSplit(training: training, testing: testing);
  }

  /// Allocates whole families (never split) across training / dev / testing,
  /// reserving at least one family for training so the fold is never empty.
  void _allocateFamilies({
    required List<List<MlTrainingExample>> families,
    required int total,
    required double devFraction,
    required double testFraction,
    required List<MlTrainingExample> training,
    required List<MlTrainingExample> dev,
    required List<MlTrainingExample> testing,
  }) {
    final nFamilies = families.length;
    if (nFamilies == 0) return;

    if (nFamilies == 1) {
      // A single family cannot be divided without splitting it; keep it in
      // training so training is never empty. Held-out coverage for this class
      // is a dataset limitation.
      training.addAll(families.single);
      return;
    }

    var targetTest = (total * testFraction).round();
    if (total >= 3 && targetTest == 0) targetTest = 1;
    var targetDev = (total * devFraction).round();
    if (total >= 5 && targetDev == 0) targetDev = 1;

    final test = <MlTrainingExample>[];
    final devList = <MlTrainingExample>[];

    // Test fold: take whole families greedily, reserving the last family for
    // training so training is never empty.
    var testCount = 0;
    var testEnd = 0;
    for (var i = 0; i < nFamilies - 1; i++) {
      if (testCount >= targetTest) break;
      test.addAll(families[i]);
      testCount += families[i].length;
      testEnd = i + 1;
    }
    // Ensure at least one held-out example per class when the class is big enough.
    if (total >= 3 && testCount == 0) {
      test.addAll(families[0]);
      testCount = families[0].length;
      testEnd = 1;
    }

    // Dev fold: take whole families after test, reserving the last family for
    // training.
    var devCount = 0;
    var devEnd = testEnd;
    for (var i = testEnd; i < nFamilies - 1; i++) {
      if (devCount >= targetDev) break;
      devList.addAll(families[i]);
      devCount += families[i].length;
      devEnd = i + 1;
    }

    // Train fold: everything not assigned to test or dev.
    for (var i = 0; i < nFamilies; i++) {
      if (i < testEnd || i < devEnd) continue;
      training.addAll(families[i]);
    }

    testing.addAll(test);
    dev.addAll(devList);
  }

  /// Allocates whole families (never split) across training / testing,
  /// reserving at least one family for training so the fold is never empty.
  void _allocateTwoWay({
    required List<List<MlTrainingExample>> families,
    required int total,
    required double testFraction,
    required List<MlTrainingExample> training,
    required List<MlTrainingExample> testing,
  }) {
    final nFamilies = families.length;
    if (nFamilies == 0) return;

    if (nFamilies == 1) {
      training.addAll(families.single);
      return;
    }

    var targetTest = (total * testFraction).round();
    if (total >= 3 && targetTest == 0) targetTest = 1;

    final test = <MlTrainingExample>[];
    var testCount = 0;
    var testEnd = 0;
    for (var i = 0; i < nFamilies - 1; i++) {
      if (testCount >= targetTest) break;
      test.addAll(families[i]);
      testCount += families[i].length;
      testEnd = i + 1;
    }
    if (total >= 3 && testCount == 0) {
      test.addAll(families[0]);
      testCount = families[0].length;
      testEnd = 1;
    }

    for (var i = 0; i < nFamilies; i++) {
      if (i < testEnd) continue;
      training.addAll(families[i]);
    }

    testing.addAll(test);
  }

  void _shuffle<T>(List<T> items, int seed) {
    var state = seed;

    for (var i = items.length - 1; i > 0; i--) {
      state = _nextState(state);

      final j = state % (i + 1);
      final temporary = items[i];
      items[i] = items[j];
      items[j] = temporary;
    }
  }

  int _nextState(int state) {
    var value = state & 0x7fffffff;
    value = (value * 1103515245 + 12345) & 0x7fffffff;
    return value;
  }

  int _testCount(int classCount) {
    return (classCount * 0.33).round();
  }
}
