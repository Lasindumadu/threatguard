import 'ml_training_example.dart';

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
}
