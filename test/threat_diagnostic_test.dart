// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/services/evaluation_dataset.dart';
import 'package:threatguard/core/services/threat_analyzer.dart';

void main() {
  test('diagnose final V0.4 level mismatches', () {
    const analyzer = ThreatAnalyzer();

    const ids = {
      'phishing_010',
      'social_005',
      'social_009',
      'legitimate_013',
      'social_011',
    };

    for (final testCase in EvaluationDataset.cases) {
      if (!ids.contains(testCase.id)) {
        continue;
      }

      final analysis = analyzer.analyze(testCase.message);

      print('');
      print('========================================');
      print(testCase.id);
      print('========================================');
      print('Message: ${testCase.message}');
      print(
        'Expected: '
        '${testCase.expectedType.name} / '
        '${testCase.expectedLevel.name}',
      );
      print(
        'Actual: '
        '${analysis.type.name} / '
        '${analysis.level.name}',
      );
      print('Score: ${analysis.riskScore}');
      print('');
      print('Indicators:');

      for (final indicator in analysis.indicators) {
        print(
          '  - ${indicator.title} | '
          '+${indicator.scoreContribution}',
        );
        print('    ${indicator.description}');
      }
    }
  });
}
