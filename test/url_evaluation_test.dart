// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/services/url_analyzer.dart';
import 'package:threatguard/core/services/url_evaluation_dataset.dart';

void main() {
  const analyzer = UrlAnalyzer();

  test('ThreatGuard URL evaluation dataset runs successfully', () {
    final cases = UrlEvaluationDataset.cases;

    expect(cases.length, 10);

    var correct = 0;

    for (final testCase in cases) {
      final urls = analyzer.analyzeAll(_extractUrls(testCase.message));

      final detected = urls.any(
        (analysis) => analysis.signals.any(
          (signal) => signal.type == testCase.expectedSignal,
        ),
      );

      final isCorrect = detected == testCase.shouldDetectSignal;

      if (isCorrect) {
        correct++;
      }

      print(
        '${testCase.id} | '
        'Expected: ${testCase.expectedSignal.name} = '
        '${testCase.shouldDetectSignal} | '
        'Actual: $detected | '
        'Correct: $isCorrect',
      );
    }

    print('');
    print('========================================');
    print('ThreatGuard URL Evaluation');
    print('========================================');
    print('Total cases: ${cases.length}');
    print('Correct cases: $correct');
    print(
      'Accuracy: '
      '${(correct / cases.length * 100).toStringAsFixed(1)}%',
    );
    print('========================================');

    expect(correct, greaterThanOrEqualTo(10));
  });
}

List<String> _extractUrls(String text) {
  final urlPattern = RegExp(r'(https?://|www\.)[^\s]+', caseSensitive: false);

  return urlPattern
      .allMatches(text)
      .map((match) => match.group(0)!)
      .map(_cleanUrl)
      .toList();
}

String _cleanUrl(String url) {
  return url.replaceAll(RegExp(r'[.,!?;:]+$'), '');
}
