import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/message_source.dart';
import 'package:threatguard/core/models/threat_analysis.dart';
import 'package:threatguard/core/models/threat_message.dart';
import 'package:threatguard/core/services/hybrid_threat_analyzer.dart';
import 'package:threatguard/core/services/logistic_regression_classifier.dart';
import 'package:threatguard/core/services/ml_feature_encoder.dart';
import 'package:threatguard/core/services/ml_training_dataset.dart';
import 'package:threatguard/core/services/sms_threat_analyzer.dart';

void main() {
  late SmsThreatAnalyzer analyzer;

  setUp(() {
    const dataset = MlTrainingDataset();
    const encoder = MlFeatureEncoder();

    final examples = dataset.build();

    final trainingVectors = examples
        .map((example) => encoder.encode(example.features))
        .toList();

    final classifier = LogisticRegressionClassifier.train(
      examples: examples,
      featureVectors: trainingVectors,
      epochs: 1000,
      learningRate: 0.05,
      l2Penalty: 0.001,
    );

    analyzer = SmsThreatAnalyzer(
      analyzer: HybridThreatAnalyzer(classifier: classifier),
    );
  });

  test('analyzes an SMS message through the hybrid engine', () {
    const message = ThreatMessage(
      id: 'sms_test_001',
      body: 'Your account is suspended. Verify your password immediately.',
      sender: 'ExampleBank',
      source: MessageSource.sms,
    );

    final result = analyzer.analyze(message);

    expect(result.ruleAnalysis.type, ThreatType.phishing);
    expect(result.finalType, ThreatType.phishing);
  });

  test('rejects non-SMS messages', () {
    const message = ThreatMessage(
      id: 'manual_test_001',
      body: 'Hello, how are you?',
      source: MessageSource.manual,
    );

    expect(() => analyzer.analyze(message), throwsArgumentError);
  });
}
