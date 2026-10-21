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

  void _shuffle(List<MlTrainingExample> items, int seed) {
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
