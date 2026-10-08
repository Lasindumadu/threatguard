// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/services/evaluation_dataset.dart';
import 'package:threatguard/core/services/threat_evaluator.dart';

void main() {
  test('ThreatGuard evaluation dataset runs successfully', () {
    const evaluator = ThreatEvaluator();

    final report = evaluator.evaluate(EvaluationDataset.cases);

    expect(report.totalCases, 105);

    for (final result in report.results) {
      print(
        '${result.testCase.id} | '
        'Expected: ${result.testCase.expectedType.name} / '
        '${result.testCase.expectedLevel.name} | '
        'Actual: ${result.actualAnalysis.type.name} / '
        '${result.actualAnalysis.level.name} | '
        'Score: ${result.actualAnalysis.riskScore} | '
        'Type correct: ${result.typeCorrect} | '
        'Level correct: ${result.levelCorrect}',
      );
    }

    print('');
    print('========================================');
    print('ThreatGuard Evaluation');
    print('========================================');
    print('Total cases: ${report.totalCases}');
    print('Correct types: ${report.correctTypes}');
    print('Correct levels: ${report.correctLevels}');
    print('Completely correct: ${report.completelyCorrect}');
    print(
      'Type accuracy: '
      '${(report.typeAccuracy * 100).toStringAsFixed(1)}%',
    );
    print(
      'Level accuracy: '
      '${(report.levelAccuracy * 100).toStringAsFixed(1)}%',
    );
    print(
      'Overall accuracy: '
      '${(report.overallAccuracy * 100).toStringAsFixed(1)}%',
    );
    print('========================================');

    expect(report.results.length, 105);
    expect(report.correctTypes, greaterThanOrEqualTo(102));
  });
}
