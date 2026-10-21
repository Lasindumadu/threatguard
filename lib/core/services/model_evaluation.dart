import '../models/ml_feature_vector.dart';

/// Per-class performance metrics.
class ClassMetrics {
  final MlThreatType type;
  final int truePositives;
  final int falsePositives;
  final int falseNegatives;
  final int support;

  const ClassMetrics({
    required this.type,
    required this.truePositives,
    required this.falsePositives,
    required this.falseNegatives,
    required this.support,
  });

  double get precision {
    final denominator = truePositives + falsePositives;
    return denominator == 0 ? 0.0 : truePositives / denominator;
  }

  double get recall {
    final denominator = truePositives + falseNegatives;
    return denominator == 0 ? 0.0 : truePositives / denominator;
  }

  /// Harmonic mean of precision and recall.
  double get f1 {
    final p = precision;
    final r = recall;
    return (p + r) == 0 ? 0.0 : 2 * p * r / (p + r);
  }
}

/// A complete, honest evaluation report for one model on one dataset.
///
/// This is the artifact a security reviewer actually reads: not "94% accurate",
/// but "recall on phishing is 0.91 and the model has never once called a
/// legitimate message phishing, on 24 held-out legitimate samples".
class ModelEvaluationReport {
  final int total;
  final int correct;
  final String datasetLabel;

  /// `matrix[actual][predicted]`.
  final Map<MlThreatType, Map<MlThreatType, int>> confusionMatrix;
  final Map<MlThreatType, ClassMetrics> perClass;

  const ModelEvaluationReport({
    required this.total,
    required this.correct,
    required this.confusionMatrix,
    required this.perClass,
    this.datasetLabel = 'test',
  });

  double get accuracy => total == 0 ? 0.0 : correct / total;

  /// Unweighted mean F1 across classes. Preferred over accuracy on skewed
  /// datasets because it does not let a large class hide a broken small one.
  double get macroF1 {
    if (perClass.isEmpty) return 0.0;
    final sum = perClass.values.fold<double>(0.0, (acc, m) => acc + m.f1);
    return sum / perClass.length;
  }

  double get macroPrecision {
    if (perClass.isEmpty) return 0.0;
    final sum = perClass.values.fold<double>(
      0.0,
      (acc, m) => acc + m.precision,
    );
    return sum / perClass.length;
  }

  double get macroRecall {
    if (perClass.isEmpty) return 0.0;
    final sum = perClass.values.fold<double>(0.0, (acc, m) => acc + m.recall);
    return sum / perClass.length;
  }

  /// Of everything the model flagged as a threat, how much really was one?
  /// This is the number that decides whether users trust the alerts.
  double get threatPrecision {
    var tp = 0;
    var fp = 0;

    for (final entry in perClass.entries) {
      if (entry.key == MlThreatType.legitimate) continue;
      tp += entry.value.truePositives;
      fp += entry.value.falsePositives;
    }

    final denominator = tp + fp;
    return denominator == 0 ? 0.0 : tp / denominator;
  }

  /// Fraction of genuinely legitimate messages the model wrongly flagged.
  /// For a consumer security app, this is the metric that drives uninstalls.
  double get falsePositiveRate {
    final legitimate = perClass[MlThreatType.legitimate];
    if (legitimate == null) return 0.0;

    final actualLegitimate =
        legitimate.truePositives + legitimate.falseNegatives;
    if (actualLegitimate == 0) return 0.0;

    return legitimate.falseNegatives / actualLegitimate;
  }

  /// Human-readable report, used by tests and the Model Insights screen.
  String toReportString() {
    final buffer = StringBuffer()
      ..writeln('ThreatGuard model evaluation — $datasetLabel set')
      ..writeln('=' * 52)
      ..writeln('Samples:        $total')
      ..writeln('Correct:        $correct')
      ..writeln('Accuracy:       ${_pct(accuracy)}')
      ..writeln('Macro precision ${_pct(macroPrecision)}')
      ..writeln('Macro recall:   ${_pct(macroRecall)}')
      ..writeln('Macro F1:       ${_pct(macroF1)}')
      ..writeln('Threat precision ${_pct(threatPrecision)}')
      ..writeln('False-positive rate ${_pct(falsePositiveRate)}')
      ..writeln('')
      ..writeln('Per class:');

    for (final type in MlThreatType.values) {
      final m = perClass[type];
      if (m == null) continue;
      buffer.writeln(
        '  ${_label(type).padRight(20)} '
        'P ${_pct(m.precision)}  '
        'R ${_pct(m.recall)}  '
        'F1 ${_pct(m.f1)}  '
        '(n=${m.support})',
      );
    }

    buffer
      ..writeln('')
      ..writeln('Confusion matrix (rows = actual, columns = predicted):');

    final header = MlThreatType.values.map((t) => _short(t).padLeft(6)).join();
    buffer.writeln('${' '.padRight(20)}$header');

    for (final actual in MlThreatType.values) {
      final row = MlThreatType.values
          .map((p) => '${confusionMatrix[actual]?[p] ?? 0}'.padLeft(6))
          .join();
      buffer.writeln('${_label(actual).padRight(20)}$row');
    }

    return buffer.toString();
  }

  static String _pct(double value) => '${(value * 100).toStringAsFixed(1)}%';

  static String _label(MlThreatType type) => switch (type) {
    MlThreatType.legitimate => 'legitimate',
    MlThreatType.spam => 'spam',
    MlThreatType.phishing => 'phishing',
    MlThreatType.scam => 'scam',
    MlThreatType.socialEngineering => 'social engineering',
  };

  static String _short(MlThreatType type) => switch (type) {
    MlThreatType.legitimate => 'legit',
    MlThreatType.spam => 'spam',
    MlThreatType.phishing => 'phish',
    MlThreatType.scam => 'scam',
    MlThreatType.socialEngineering => 'social',
  };
}

/// Builds a [ModelEvaluationReport] from a list of (actual, predicted) pairs.
class ModelEvaluator {
  const ModelEvaluator();

  ModelEvaluationReport evaluate({
    required List<MlThreatType> actual,
    required List<MlThreatType> predicted,
    String datasetLabel = 'test',
  }) {
    assert(
      actual.length == predicted.length,
      'actual and predicted must be the same length',
    );

    final matrix = <MlThreatType, Map<MlThreatType, int>>{
      for (final a in MlThreatType.values)
        a: {for (final p in MlThreatType.values) p: 0},
    };

    var correct = 0;

    for (var i = 0; i < actual.length; i++) {
      final a = actual[i];
      final p = predicted[i];
      matrix[a]![p] = (matrix[a]![p] ?? 0) + 1;
      if (a == p) correct++;
    }

    final perClass = <MlThreatType, ClassMetrics>{};

    for (final type in MlThreatType.values) {
      final tp = matrix[type]![type] ?? 0;

      var fp = 0;
      for (final other in MlThreatType.values) {
        if (other == type) continue;
        fp += matrix[other]![type] ?? 0;
      }

      var fn = 0;
      for (final other in MlThreatType.values) {
        if (other == type) continue;
        fn += matrix[type]![other] ?? 0;
      }

      perClass[type] = ClassMetrics(
        type: type,
        truePositives: tp,
        falsePositives: fp,
        falseNegatives: fn,
        support: tp + fn,
      );
    }

    return ModelEvaluationReport(
      total: actual.length,
      correct: correct,
      confusionMatrix: matrix,
      perClass: perClass,
      datasetLabel: datasetLabel,
    );
  }
}
