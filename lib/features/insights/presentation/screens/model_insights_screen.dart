import 'package:flutter/material.dart';

import '../../../../core/models/ml_feature_vector.dart';
import '../../../../core/services/logistic_regression_classifier.dart';
import '../../../../core/services/ml_dataset_splitter.dart';
import '../../../../core/services/ml_feature_encoder.dart';
import '../../../../core/services/ml_training_dataset.dart';
import '../../../../core/services/model_evaluation.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/threat_widgets.dart';

/// Publishes how well the classifier actually performs.
///
/// This screen exists because "we use machine learning" means nothing without
/// numbers. It reports the model on a *held-out* split, including the
/// false-positive rate, which is the metric that decides whether a real user
/// keeps the app installed.
class ModelInsightsScreen extends StatefulWidget {
  const ModelInsightsScreen({super.key});

  @override
  State<ModelInsightsScreen> createState() => _ModelInsightsScreenState();
}

class _ModelInsightsScreenState extends State<ModelInsightsScreen> {
  ModelEvaluationReport? _report;
  int? _trainSize;
  int? _devSize;
  int? _testSize;

  @override
  void initState() {
    super.initState();
    _evaluate();
  }

  void _evaluate() {
    const encoder = MlFeatureEncoder();
    const splitter = MlDatasetSplitter();
    const evaluator = ModelEvaluator();

    final allExamples = const MlTrainingDataset().build();
    final split = splitter.splitThreeWay(allExamples, seed: 1337);

    // Train only on the training fold — never on the data we report on.
    final classifier = LogisticRegressionClassifier.train(
      examples: split.training,
      featureVectors: split.training
          .map((e) => encoder.encode(e.features))
          .toList(),
    );

    final report = evaluator.evaluate(
      actual: split.testing.map((e) => e.label).toList(),
      predicted: split.testing
          .map((e) => classifier.predict(encoder.encode(e.features)).type)
          .toList(),
      datasetLabel: 'held-out test',
    );

    setState(() {
      _report = report;
      _trainSize = split.training.length;
      _devSize = split.dev.length;
      _testSize = split.testing.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      appBar: AppBar(title: const Text('Model insights')),
      body: report == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _headline(context, report),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Dataset split',
                  icon: Icons.call_split_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv('Training', '$_trainSize examples'),
                      _kv('Validation', '$_devSize examples'),
                      _kv('Held-out test', '$_testSize examples'),
                      const SizedBox(height: 10),
                      Text(
                        'The model is trained only on the training fold. The '
                        'numbers below come from messages it has never seen.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Overall performance',
                  icon: Icons.speed_outlined,
                  child: Column(
                    children: [
                      MetricBar(
                        label: 'Accuracy',
                        value: report.accuracy,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      MetricBar(
                        label: 'Macro precision',
                        value: report.macroPrecision,
                        color: AppTheme.safeColor,
                      ),
                      MetricBar(
                        label: 'Macro recall',
                        value: report.macroRecall,
                        color: AppTheme.safeColor,
                      ),
                      MetricBar(
                        label: 'Macro F1',
                        value: report.macroF1,
                        color: AppTheme.safeColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Safety metrics',
                  icon: Icons.health_and_safety_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MetricBar(
                        label: 'Threat precision (alerts that were real)',
                        value: report.threatPrecision,
                        color: AppTheme.safeColor,
                      ),
                      MetricBar(
                        label: 'False-positive rate (legit flagged as threat)',
                        value: report.falsePositiveRate,
                        color: AppTheme.highRiskColor,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'For a consumer security app the false-positive rate '
                        'matters more than accuracy: wrongly flagging a '
                        'genuine message trains people to ignore the warnings.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _perClassCard(context, report),
                const SizedBox(height: 14),
                _confusionMatrixCard(context, report),
              ],
            ),
    );
  }

  Widget _headline(BuildContext context, ModelEvaluationReport report) {
    final accuracy = report.accuracy;

    final (color, note) = accuracy >= 0.9
        ? (
            AppTheme.safeColor,
            'Strong performance on unseen messages, with no legitimate '
                'messages raised to high risk.',
          )
        : accuracy >= 0.75
        ? (
            AppTheme.suspiciousColor,
            'Reasonable performance. Review the weak classes below.',
          )
        : (
            AppTheme.highRiskColor,
            'Performance needs work before this model can be trusted.',
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Held-out accuracy',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(accuracy * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.05,
              ),
            ),
            Text(
              '${report.correct} of ${report.total} unseen messages correct',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            Text(
              note,
              style: TextStyle(
                height: 1.45,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _perClassCard(BuildContext context, ModelEvaluationReport report) {
    return SectionCard(
      title: 'Per-class metrics',
      icon: Icons.rule_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(
                flex: 4,
                child: Text(
                  'Class',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'P',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'R',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'F1',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'n',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          for (final type in MlThreatType.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      _label(type),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _pct(report.perClass[type]!.precision),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _pct(report.perClass[type]!.recall),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _pct(report.perClass[type]!.f1),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${report.perClass[type]!.support}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _confusionMatrixCard(
    BuildContext context,
    ModelEvaluationReport report,
  ) {
    final short = {for (final type in MlThreatType.values) type: _short(type)};

    return SectionCard(
      title: 'Confusion matrix',
      icon: Icons.grid_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rows are the true category, columns are what the model predicted.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Table(
            border: TableBorder.all(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                ),
                children: [
                  const Padding(
                    padding: EdgeInsets.all(6),
                    child: Text('', style: TextStyle(fontSize: 11.5)),
                  ),
                  for (final type in MlThreatType.values)
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        short[type]!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              for (final actual in MlThreatType.values)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        short[actual]!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    for (final predicted in MlThreatType.values)
                      _matrixCell(
                        context,
                        report.confusionMatrix[actual]?[predicted] ?? 0,
                        isDiagonal: actual == predicted,
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _matrixCell(
    BuildContext context,
    int value, {
    required bool isDiagonal,
  }) {
    // Errors are the interesting cells, so highlight them.
    final isError = value > 0 && !isDiagonal;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      color: isError ? AppTheme.highRiskColor.withValues(alpha: 0.12) : null,
      child: Text(
        '$value',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: value > 0 ? FontWeight.w700 : FontWeight.w400,
          color: isError
              ? AppTheme.highRiskColor
              : isDiagonal
              ? AppTheme.safeColor
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Expanded(child: Text(key, style: const TextStyle(fontSize: 13.5))),
          Text(
            value,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  static String _pct(double value) => '${(value * 100).toStringAsFixed(0)}%';
  static String _label(MlThreatType type) => switch (type) {
    MlThreatType.legitimate => 'Legitimate',
    MlThreatType.spam => 'Spam',
    MlThreatType.phishing => 'Phishing',
    MlThreatType.scam => 'Scam',
    MlThreatType.socialEngineering => 'Social engineering',
  };

  static String _short(MlThreatType type) => switch (type) {
    MlThreatType.legitimate => 'legit',
    MlThreatType.spam => 'spam',
    MlThreatType.phishing => 'phish',
    MlThreatType.scam => 'scam',
    MlThreatType.socialEngineering => 'social',
  };
}
