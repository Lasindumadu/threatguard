// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/services/threat_analyzer.dart';
import 'package:threatguard/core/services/url_analyzer.dart';
import 'package:threatguard/core/services/url_threat_evaluation_dataset.dart';

void main() {
  const threatAnalyzer = ThreatAnalyzer();
  const urlAnalyzer = UrlAnalyzer();

  test('ThreatGuard URL + threat evaluation runs successfully', () {
    final cases = UrlThreatEvaluationDataset.cases;

    expect(cases.length, 10);

    var correct = 0;

    for (final testCase in cases) {
      final threatResult = threatAnalyzer.analyze(testCase.message);

      final urls = _extractUrls(testCase.message);

      final urlAnalyses = urlAnalyzer.analyzeAll(urls);

      final urlSignalDetected = urlAnalyses.any(
        (analysis) => analysis.signals.any(
          (signal) => signal.type == testCase.expectedUrlSignal,
        ),
      );

      final typeCorrect = threatResult.type == testCase.expectedThreatType;

      final levelCorrect = threatResult.level == testCase.expectedThreatLevel;

      final completelyCorrect =
          urlSignalDetected && typeCorrect && levelCorrect;

      if (completelyCorrect) {
        correct++;
      }

      print(
        '${testCase.id} | '
        'URL signal: ${testCase.expectedUrlSignal.name} '
        '=> $urlSignalDetected | '
        'Expected threat: '
        '${testCase.expectedThreatType.name} / '
        '${testCase.expectedThreatLevel.name} | '
        'Actual threat: '
        '${threatResult.type.name} / '
        '${threatResult.level.name} | '
        'Score: ${threatResult.riskScore} | '
        'Correct: $completelyCorrect',
      );
    }

    print('');
    print('========================================');
    print('ThreatGuard URL + Threat Evaluation');
    print('========================================');
    print('Total cases: ${cases.length}');
    print('Completely correct: $correct');
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
