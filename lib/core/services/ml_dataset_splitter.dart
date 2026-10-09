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
      _shuffle(group, seed);
      shuffledGroups[entry.key] = group;
    }

    return _splitByGroups(examplesByClass: shuffledGroups);
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
      final testCount = _testCount(group.length);

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
