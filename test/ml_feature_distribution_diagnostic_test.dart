// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/models/ml_feature_vector.dart';
import 'package:threatguard/core/models/ml_training_example.dart';

import 'package:threatguard/core/services/ml_feature_encoder.dart';
import 'package:threatguard/core/services/ml_training_dataset.dart';

void main() {
  test('analyzes feature distribution across threat classes', () {
    const dataset = MlTrainingDataset();
    const encoder = MlFeatureEncoder();

    final examples = dataset.build();

    print('');
    print('===== ML FEATURE DISTRIBUTION =====');
    print('Total examples: ${examples.length}');
    print('');

    final grouped = <MlThreatType, List<MlTrainingExample>>{
      for (final type in MlThreatType.values) type: [],
    };

    for (final example in examples) {
      grouped[example.label]!.add(example);
    }

    print('Class counts:');

    for (final type in MlThreatType.values) {
      print('  ${type.name}: ${grouped[type]!.length}');
    }

    print('');
    print('----- BOOLEAN FEATURE DISTRIBUTION -----');
    print('');

    final featureNames = <String>[
      'hasUrgency',
      'hasAccountSecurity',
      'hasCredential',
      'hasFinancial',
      'hasPrizeReward',
      'hasSecrecy',
      'hasAuthority',
      'hasPromotion',
      'hasUrl',
      'hasSuspiciousUrl',
      'hasIpUrl',
      'hasPunycodeUrl',
      'hasEmbeddedCredentialsUrl',
      'hasNonStandardPortUrl',
      'hasExcessiveSubdomainsUrl',
      'hasShortenerUrl',
      'hasAccountVerification',
      'hasIdentityVerification',
      'hasCredentialRequest',
      'hasStrongCredentialRequest',
      'hasPrizeFinancialCombination',
      'hasAccountCredentialCombination',
      'hasAuthorityCredentialCombination',
      'hasUrgencyCredentialCombination',
    ];

    for (final featureName in featureNames) {
      print(featureName);

      for (final type in MlThreatType.values) {
        final examplesForClass = grouped[type]!;

        final trueCount = examplesForClass
            .where(
              (example) => _getBooleanFeature(example.features, featureName),
            )
            .length;

        final percentage = trueCount / examplesForClass.length * 100;

        print(
          '  ${type.name.padRight(20)} '
          '$trueCount/${examplesForClass.length} '
          '(${percentage.toStringAsFixed(1)}%)',
        );
      }

      print('');
    }

    print('----- NUMERIC FEATURE DISTRIBUTION -----');
    print('');

    final numericFeatures = <String, int Function(MlFeatureVector)>{
      'messageLength': (features) => features.messageLength,
      'wordCount': (features) => features.wordCount,
      'urlCount': (features) => features.urlCount,
    };

    for (final entry in numericFeatures.entries) {
      print(entry.key);

      for (final type in MlThreatType.values) {
        final values = grouped[type]!
            .map((example) => entry.value(example.features))
            .toList();

        final mean = values.reduce((a, b) => a + b) / values.length;

        final minimum = values.reduce((a, b) => a < b ? a : b);

        final maximum = values.reduce((a, b) => a > b ? a : b);

        print(
          '  ${type.name.padRight(20)} '
          'mean=${mean.toStringAsFixed(1)}, '
          'min=$minimum, '
          'max=$maximum',
        );
      }

      print('');
    }

    print('----- ENCODED FEATURE ORDER -----');
    print('');

    final firstExample = examples.first;

    final encoded = encoder.encode(firstExample.features);

    final encodedFeatureNames = <String>[
      'messageLength',
      'wordCount',
      'urlCount',
      ...featureNames,
    ];

    print('Total encoded features: ${encoded.length}');

    for (var i = 0; i < encoded.length; i++) {
      print('  [$i] ${encodedFeatureNames[i]} = ${encoded[i]}');
    }

    print('');
    print('====================================');
    print('');

    expect(examples.length, 105);
    expect(encoded.length, encodedFeatureNames.length);
  });
}

bool _getBooleanFeature(MlFeatureVector features, String featureName) {
  switch (featureName) {
    case 'hasUrgency':
      return features.hasUrgency;
    case 'hasAccountSecurity':
      return features.hasAccountSecurity;
    case 'hasCredential':
      return features.hasCredential;
    case 'hasFinancial':
      return features.hasFinancial;
    case 'hasPrizeReward':
      return features.hasPrizeReward;
    case 'hasSecrecy':
      return features.hasSecrecy;
    case 'hasAuthority':
      return features.hasAuthority;
    case 'hasPromotion':
      return features.hasPromotion;
    case 'hasUrl':
      return features.hasUrl;
    case 'hasSuspiciousUrl':
      return features.hasSuspiciousUrl;
    case 'hasIpUrl':
      return features.hasIpUrl;
    case 'hasPunycodeUrl':
      return features.hasPunycodeUrl;
    case 'hasEmbeddedCredentialsUrl':
      return features.hasEmbeddedCredentialsUrl;
    case 'hasNonStandardPortUrl':
      return features.hasNonStandardPortUrl;
    case 'hasExcessiveSubdomainsUrl':
      return features.hasExcessiveSubdomainsUrl;
    case 'hasShortenerUrl':
      return features.hasShortenerUrl;
    case 'hasAccountVerification':
      return features.hasAccountVerification;
    case 'hasIdentityVerification':
      return features.hasIdentityVerification;
    case 'hasCredentialRequest':
      return features.hasCredentialRequest;
    case 'hasStrongCredentialRequest':
      return features.hasStrongCredentialRequest;
    case 'hasPrizeFinancialCombination':
      return features.hasPrizeFinancialCombination;
    case 'hasAccountCredentialCombination':
      return features.hasAccountCredentialCombination;
    case 'hasAuthorityCredentialCombination':
      return features.hasAuthorityCredentialCombination;
    case 'hasUrgencyCredentialCombination':
      return features.hasUrgencyCredentialCombination;
    default:
      throw ArgumentError('Unknown feature: $featureName');
  }
}
