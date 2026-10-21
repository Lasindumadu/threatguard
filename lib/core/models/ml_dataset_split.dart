import 'ml_training_example.dart';
import 'ml_feature_vector.dart';

class MlDatasetSplit {
  final List<MlTrainingExample> training;
  final List<MlTrainingExample> testing;

  /// Optional validation fold used for threshold tuning. Empty for the
  /// two-way [MlDatasetSplitter.split] variants.
  final List<MlTrainingExample> dev;

  const MlDatasetSplit({
    required this.training,
    required this.testing,
    this.dev = const [],
  });

  int get total => training.length + dev.length + testing.length;

  /// Number of examples per class in each fold.
  Map<MlThreatType, int> get trainingByClass => _countByClass(training);
  Map<MlThreatType, int> get devByClass => _countByClass(dev);
  Map<MlThreatType, int> get testingByClass => _countByClass(testing);

  static Map<MlThreatType, int> _countByClass(
    List<MlTrainingExample> examples,
  ) {
    final counts = <MlThreatType, int>{};
    for (final type in MlThreatType.values) {
      counts[type] = 0;
    }
    for (final example in examples) {
      counts[example.label] = (counts[example.label] ?? 0) + 1;
    }
    return counts;
  }
}
