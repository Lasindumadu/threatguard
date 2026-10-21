// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/threat_analysis.dart';
import 'package:threatguard/core/services/evaluation_dataset.dart';
import 'package:threatguard/core/services/threat_analyzer.dart';

void main() {
  test('rule engine meets the documented overall accuracy floor', () {
    const analyzer = ThreatAnalyzer();

    var correctTypes = 0;
    var correctLevels = 0;
    var completelyCorrect = 0;

    final mismatches = <String>[];

    for (final testCase in EvaluationDataset.cases) {
      final analysis = analyzer.analyze(testCase.message);

      final typeOk = analysis.type == testCase.expectedType;
      final levelOk = analysis.level == testCase.expectedLevel;

      if (typeOk) correctTypes++;
      if (levelOk) correctLevels++;
      if (typeOk && levelOk) completelyCorrect++;

      if (!typeOk || !levelOk) {
        mismatches.add(
          '${testCase.id}: expected '
          '${testCase.expectedType.name}/${testCase.expectedLevel.name}, '
          'got ${analysis.type.name}/${analysis.level.name} '
          '(score ${analysis.riskScore})',
        );
      }
    }

    final total = EvaluationDataset.cases.length;
    final typeAccuracy = correctTypes / total;
    final levelAccuracy = correctLevels / total;
    final overall = completelyCorrect / total;

    print('ThreatGuard rule-engine evaluation');
    print('Total cases:       $total');
    print('Type accuracy:     ${(typeAccuracy * 100).toStringAsFixed(1)}%');
    print('Level accuracy:    ${(levelAccuracy * 100).toStringAsFixed(1)}%');
    print('Overall accuracy:  ${(overall * 100).toStringAsFixed(1)}%');

    if (mismatches.isNotEmpty) {
      print('Mismatches:');
      for (final mismatch in mismatches) {
        print('  - $mismatch');
      }
    }

    // Floors, not targets. These fail if the rule engine regresses, which the
    // previous print-only version of this test could never do.
    expect(typeAccuracy, greaterThanOrEqualTo(0.90));
    expect(levelAccuracy, greaterThanOrEqualTo(0.90));
    expect(overall, greaterThanOrEqualTo(0.85));
  });

  test('rule engine never flags obviously legitimate messages as high risk', () {
    const analyzer = ThreatAnalyzer();

    final legitimate = EvaluationDataset.cases.where(
      (c) => c.expectedType == ThreatType.legitimate,
    );

    for (final testCase in legitimate) {
      final analysis = analyzer.analyze(testCase.message);

      expect(
        analysis.level,
        isNot(ThreatLevel.highRisk),
        reason: '${testCase.id} raised a high-risk alert on a legitimate '
            'message — this is the worst failure mode for a consumer app',
      );
    }
  });
}
