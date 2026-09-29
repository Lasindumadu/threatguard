import 'dart:math' as math;

import '../models/ml_feature_vector.dart';
import '../models/ml_training_example.dart';
import 'ml_classifier.dart';
import '../models/ml_prediction.dart';

class LogisticRegressionClassifier implements MlClassifier {
  final List<List<double>> weights;
  final List<double> means;
  final List<double> standardDeviations;
  final List<MlThreatType> classes;

  const LogisticRegressionClassifier._({
    required this.weights,
    required this.means,
    required this.standardDeviations,
    required this.classes,
  });

  factory LogisticRegressionClassifier.train({
    required List<MlTrainingExample> examples,
    required List<List<double>> featureVectors,
    int epochs = 1000,
    double learningRate = 0.05,
    double l2Penalty = 0.001,
  }) {
    if (examples.isEmpty) {
      throw ArgumentError('Training examples cannot be empty.');
    }

    if (examples.length != featureVectors.length) {
      throw ArgumentError(
        'Examples and feature vectors must have the same length.',
      );
    }

    final featureCount = featureVectors.first.length;

    if (featureCount == 0) {
      throw ArgumentError('Feature vectors cannot be empty.');
    }

    for (final vector in featureVectors) {
      if (vector.length != featureCount) {
        throw ArgumentError('All feature vectors must have the same length.');
      }
    }

    final classes = MlThreatType.values;

    final means = List<double>.filled(featureCount, 0.0);
    final standardDeviations = List<double>.filled(featureCount, 1.0);

    // Calculate feature means.
    for (final vector in featureVectors) {
      for (var j = 0; j < featureCount; j++) {
        means[j] += vector[j];
      }
    }

    for (var j = 0; j < featureCount; j++) {
      means[j] /= featureVectors.length;
    }

    // Calculate feature standard deviations.
    for (final vector in featureVectors) {
      for (var j = 0; j < featureCount; j++) {
        final difference = vector[j] - means[j];
        standardDeviations[j] += difference * difference;
      }
    }

    for (var j = 0; j < featureCount; j++) {
      final variance = (standardDeviations[j] - 1.0) / featureVectors.length;

      final standardDeviation = math.sqrt(variance < 0 ? 0 : variance);

      standardDeviations[j] = standardDeviation < 1e-9
          ? 1.0
          : standardDeviation;
    }

    final normalizedFeatures = featureVectors
        .map((vector) => _normalize(vector, means, standardDeviations))
        .toList();

    // One row per class.
    // The final column is the bias/intercept.
    final weights = List.generate(
      classes.length,
      (_) => List<double>.filled(featureCount + 1, 0.0),
    );

    for (var epoch = 0; epoch < epochs; epoch++) {
      final gradients = List.generate(
        classes.length,
        (_) => List<double>.filled(featureCount + 1, 0.0),
      );

      for (var i = 0; i < normalizedFeatures.length; i++) {
        final input = <double>[...normalizedFeatures[i], 1.0];

        final probabilities = _softmax(weights, input);

        final actualClass = classes.indexOf(examples[i].label);

        for (var classIndex = 0; classIndex < classes.length; classIndex++) {
          final target = classIndex == actualClass ? 1.0 : 0.0;
          final error = probabilities[classIndex] - target;

          for (var j = 0; j < input.length; j++) {
            gradients[classIndex][j] += error * input[j];
          }
        }
      }

      final sampleCount = normalizedFeatures.length;

      for (var classIndex = 0; classIndex < classes.length; classIndex++) {
        for (var j = 0; j < featureCount + 1; j++) {
          gradients[classIndex][j] /= sampleCount;

          // Do not regularize the bias.
          if (j < featureCount) {
            gradients[classIndex][j] += l2Penalty * weights[classIndex][j];
          }

          weights[classIndex][j] -= learningRate * gradients[classIndex][j];
        }
      }
    }

    return LogisticRegressionClassifier._(
      weights: weights,
      means: means,
      standardDeviations: standardDeviations,
      classes: classes,
    );
  }

  @override
  MlPrediction predict(List<double> features) {
    if (features.length != means.length) {
      throw ArgumentError(
        'Expected ${means.length} features, '
        'but received ${features.length}.',
      );
    }

    final normalized = _normalize(features, means, standardDeviations);

    final input = <double>[...normalized, 1.0];

    final probabilities = _softmax(weights, input);

    var bestIndex = 0;

    for (var i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > probabilities[bestIndex]) {
        bestIndex = i;
      }
    }

    return MlPrediction(
      type: classes[bestIndex],
      confidence: probabilities[bestIndex],
    );
  }

  static List<double> _normalize(
    List<double> features,
    List<double> means,
    List<double> standardDeviations,
  ) {
    return List.generate(
      features.length,
      (index) => (features[index] - means[index]) / standardDeviations[index],
    );
  }

  static List<double> _softmax(List<List<double>> weights, List<double> input) {
    final logits = <double>[];

    for (final classWeights in weights) {
      var logit = 0.0;

      for (var j = 0; j < input.length; j++) {
        logit += classWeights[j] * input[j];
      }

      logits.add(logit);
    }

    final maxLogit = logits.reduce(math.max);

    final exponentials = logits
        .map((logit) => math.exp((logit - maxLogit).clamp(-60.0, 60.0)))
        .toList();

    final total = exponentials.fold<double>(0.0, (sum, value) => sum + value);

    return exponentials.map((value) => value / total).toList();
  }
}
