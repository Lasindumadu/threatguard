// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/models/ml_feature_vector.dart';
import 'package:threatguard/core/services/ml_training_dataset.dart';

void main() {
  test('prints ML dataset summary and interaction feature usage', () {
    const dataset = MlTrainingDataset();

    final examples = dataset.build();

    final counts = <MlThreatType, int>{
      for (final type in MlThreatType.values) type: 0,
    };

    var prizeFinancialCount = 0;
    var accountCredentialCount = 0;
    var authorityCredentialCount = 0;
    var urgencyCredentialCount = 0;

    for (final example in examples) {
      counts[example.label] = counts[example.label]! + 1;

      final f = example.features;

      if (f.hasPrizeFinancialCombination) {
        prizeFinancialCount++;
      }

      if (f.hasAccountCredentialCombination) {
        accountCredentialCount++;
      }

      if (f.hasAuthorityCredentialCombination) {
        authorityCredentialCount++;
      }

      if (f.hasUrgencyCredentialCombination) {
        urgencyCredentialCount++;
      }
    }

    print('');
    print('===== THREATGUARD ML DATASET SUMMARY =====');
    print('Total examples: ${examples.length}');
    print('');

    for (final type in MlThreatType.values) {
      print('${type.name}: ${counts[type]}');
    }

    print('');
    print('===== INTERACTION FEATURE USAGE =====');
    print(
      'Prize + Financial: '
      '$prizeFinancialCount cases',
    );
    print(
      'Account + Credential: '
      '$accountCredentialCount cases',
    );
    print(
      'Authority + Credential: '
      '$authorityCredentialCount cases',
    );
    print(
      'Urgency + Credential: '
      '$urgencyCredentialCount cases',
    );

    print('');
    print('===== CASES WITH INTERACTION FEATURES =====');

    for (final example in examples) {
      final f = example.features;

      final hasInteraction =
          f.hasPrizeFinancialCombination ||
          f.hasAccountCredentialCombination ||
          f.hasAuthorityCredentialCombination ||
          f.hasUrgencyCredentialCombination;

      if (!hasInteraction) {
        continue;
      }

      final interactions = <String>[];

      if (f.hasPrizeFinancialCombination) {
        interactions.add('prize+financial');
      }

      if (f.hasAccountCredentialCombination) {
        interactions.add('account+credential');
      }

      if (f.hasAuthorityCredentialCombination) {
        interactions.add('authority+credential');
      }

      if (f.hasUrgencyCredentialCombination) {
        interactions.add('urgency+credential');
      }

      print(
        '${f.caseId} | '
        'label=${example.label.name} | '
        '${interactions.join(', ')}',
      );
    }

    print('');
    print('============================================');
  });
}
