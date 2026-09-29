import '../models/ml_dataset_split.dart';
import '../models/ml_training_example.dart';
import '../models/ml_feature_vector.dart';

class MlDatasetSplitter {
  const MlDatasetSplitter();

  MlDatasetSplit split(List<MlTrainingExample> examples) {
    final groups = <MlThreatType, List<MlTrainingExample>>{
      for (final type in MlThreatType.values) type: [],
    };

    for (final example in examples) {
      groups[example.label]!.add(example);
    }

    final training = <MlTrainingExample>[];
    final testing = <MlTrainingExample>[];

    for (final group in groups.values) {
      final testCount = _testCount(group.length);

      testing.addAll(group.take(testCount));
      training.addAll(group.skip(testCount));
    }

    return MlDatasetSplit(training: training, testing: testing);
  }

  int _testCount(int classCount) {
    return (classCount * 0.33).round();
  }
}
