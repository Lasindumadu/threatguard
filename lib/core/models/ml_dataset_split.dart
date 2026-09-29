import 'ml_training_example.dart';

class MlDatasetSplit {
  final List<MlTrainingExample> training;
  final List<MlTrainingExample> testing;

  const MlDatasetSplit({required this.training, required this.testing});
}
