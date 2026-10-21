import 'ml_feature_vector.dart';

/// A single classifier verdict, plus the full probability distribution.
///
/// The distribution matters more than the winning label: it lets the UI show
/// "62% phishing / 31% scam" instead of an unaccountable "phishing", and it
/// lets the arbitration layer know how *decisive* the model actually was.
class MlPrediction {
  final MlThreatType type;
  final double confidence;

  /// Probability for every class, in the same order as [MlThreatType.values].
  final List<double> probabilities;

  const MlPrediction({
    required this.type,
    required this.confidence,
    this.probabilities = const [],
  });

  /// Distance between the top class and the runner-up.
  ///
  /// A 0.05 margin between phishing and scam means the model cannot tell them
  /// apart, which is exactly the situation where the rules should win.
  double get margin {
    if (probabilities.length < 2) return confidence;

    final sorted = [...probabilities]..sort((a, b) => b.compareTo(a));
    return sorted[0] - sorted[1];
  }

  double probabilityOf(MlThreatType other) {
    if (probabilities.length != MlThreatType.values.length) {
      return other == type ? confidence : 0.0;
    }
    return probabilities[MlThreatType.values.indexOf(other)];
  }

  /// Map of class -> probability, for display and serialization.
  Map<MlThreatType, double> get distribution {
    if (probabilities.length != MlThreatType.values.length) {
      return {type: confidence};
    }

    return {
      for (var i = 0; i < MlThreatType.values.length; i++)
        MlThreatType.values[i]: probabilities[i],
    };
  }
}
