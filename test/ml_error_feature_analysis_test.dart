// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/ml_feature_vector.dart';
import 'package:threatguard/core/services/evaluation_dataset.dart';
import 'package:threatguard/core/services/logistic_regression_classifier.dart';
import 'package:threatguard/core/services/ml_feature_encoder.dart';
import 'package:threatguard/core/services/ml_feature_extractor.dart';
import 'package:threatguard/core/services/ml_training_dataset.dart';

void main() {
  test('prints detailed feature analysis for current ML errors', () {
    const extractor = MlFeatureExtractor();
    const encoder = MlFeatureEncoder();
    const datasetBuilder = MlTrainingDataset(extractor: extractor);

    final examples = datasetBuilder.build();

    final featureVectors = examples
        .map((example) => encoder.encode(example.features))
        .toList();

    final classifier = LogisticRegressionClassifier.train(
      examples: examples,
      featureVectors: featureVectors,
    );

    final targetIds = <String>{
      'phishing_013',
      'scam_018',
      'scam_013',
      'legitimate_019',
      'social_018',
    };

    print('');
    print('============================================================');
    print('THREATGUARD V0.6 — ML ERROR FEATURE ANALYSIS');
    print('============================================================');

    for (var i = 0; i < examples.length; i++) {
      final example = examples[i];

      if (!targetIds.contains(example.features.caseId)) {
        continue;
      }

      final prediction = classifier.predict(featureVectors[i]);

      print('');
      print('------------------------------------------------------------');
      print('CASE: ${example.features.caseId}');
      print('------------------------------------------------------------');

      print('Expected: ${example.label}');
      print('Predicted: ${prediction.type}');
      print(
        'Confidence: '
        '${(prediction.confidence * 100).toStringAsFixed(2)}%',
      );

      final originalCase = EvaluationDataset.cases.firstWhere(
        (evaluationCase) => evaluationCase.id == example.features.caseId,
      );

      print('');
      print('MESSAGE:');
      print(originalCase.message);

      _printFeatures(example.features);
    }

    print('');
    print('============================================================');
    print('END OF ERROR ANALYSIS');
    print('============================================================');
  });
}

void _printFeatures(MlFeatureVector features) {
  print('');
  print('NUMERIC FEATURES');
  print('  messageLength: ${features.messageLength}');
  print('  wordCount: ${features.wordCount}');
  print('  urlCount: ${features.urlCount}');

  print('');
  print('THREAT SIGNAL FEATURES');
  print('  urgency: ${features.hasUrgency}');
  print('  accountSecurity: ${features.hasAccountSecurity}');
  print('  credential: ${features.hasCredential}');
  print('  financial: ${features.hasFinancial}');
  print('  prizeReward: ${features.hasPrizeReward}');
  print('  secrecy: ${features.hasSecrecy}');
  print('  authority: ${features.hasAuthority}');
  print('  promotion: ${features.hasPromotion}');

  print('');
  print('URL FEATURES');
  print('  hasUrl: ${features.hasUrl}');
  print('  suspiciousUrl: ${features.hasSuspiciousUrl}');
  print('  ipUrl: ${features.hasIpUrl}');
  print('  punycodeUrl: ${features.hasPunycodeUrl}');
  print(
    '  embeddedCredentialsUrl: '
    '${features.hasEmbeddedCredentialsUrl}',
  );
  print(
    '  nonStandardPortUrl: '
    '${features.hasNonStandardPortUrl}',
  );
  print(
    '  excessiveSubdomainsUrl: '
    '${features.hasExcessiveSubdomainsUrl}',
  );
  print('  shortenerUrl: ${features.hasShortenerUrl}');

  print('');
  print('SEMANTIC FEATURES');
  print(
    '  accountVerification: '
    '${features.hasAccountVerification}',
  );
  print(
    '  identityVerification: '
    '${features.hasIdentityVerification}',
  );
  print(
    '  credentialRequest: '
    '${features.hasCredentialRequest}',
  );
  print(
    '  strongCredentialRequest: '
    '${features.hasStrongCredentialRequest}',
  );

  print('');
  print('INTERACTION FEATURES');
  print(
    '  prizeFinancial: '
    '${features.hasPrizeFinancialCombination}',
  );
  print(
    '  accountCredential: '
    '${features.hasAccountCredentialCombination}',
  );
  print(
    '  authorityCredential: '
    '${features.hasAuthorityCredentialCombination}',
  );
  print(
    '  urgencyCredential: '
    '${features.hasUrgencyCredentialCombination}',
  );
}
