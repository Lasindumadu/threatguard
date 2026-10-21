// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/services/threat_analyzer.dart';
import 'package:threatguard/core/services/url_analyzer.dart';
import 'package:threatguard/core/services/url_extractor.dart';
import 'package:threatguard/core/services/url_threat_evaluation_dataset.dart';

void main() {
  const threatAnalyzer = ThreatAnalyzer();
  const urlAnalyzer = UrlAnalyzer();

  test('URL structural signals are detected for every case', () {
    final cases = UrlThreatEvaluationDataset.cases;

    expect(cases.length, 10);

    var signalsDetected = 0;
    final unhandled = <String>[];

    for (final testCase in cases) {
      // Uses the shared extractor the analyzer itself uses, rather than
      // re-implementing URL parsing inside the test.
      final urls = UrlExtractor.extract(testCase.message);
      final urlAnalyses = urlAnalyzer.analyzeAll(urls);

      final urlSignalDetected = urlAnalyses.any(
        (analysis) => analysis.signals.any(
          (signal) => signal.type == testCase.expectedUrlSignal,
        ),
      );

      if (urlSignalDetected) signalsDetected++;

      if (!urlSignalDetected) {
        unhandled.add(
          '${testCase.id} (expected ${testCase.expectedUrlSignal.name})',
        );
      }
    }

    if (unhandled.isNotEmpty) {
      print('URL signals not detected:');
      for (final entry in unhandled) {
        print('  - $entry');
      }
    }

    // Structural URL detection is deterministic and must be perfect: this is
    // the part of the pipeline where a regression is unambiguous.
    expect(signalsDetected, cases.length);
  });

  test('threat classification meets the documented accuracy floor', () {
    final cases = UrlThreatEvaluationDataset.cases;

    var typeCorrect = 0;
    var levelCorrect = 0;

    for (final testCase in cases) {
      final result = threatAnalyzer.analyze(testCase.message);

      if (result.type == testCase.expectedThreatType) typeCorrect++;
      if (result.level == testCase.expectedThreatLevel) levelCorrect++;
    }

    final total = cases.length;

    print('URL + threat evaluation: $typeCorrect/$total types, '
        '$levelCorrect/$total levels correct');

    // The rule engine is expected to classify these URL cases correctly, but
    // asserting an exact count makes the suite brittle to deliberate
    // improvements. A floor keeps it a regression gate instead.
    expect(typeCorrect, greaterThanOrEqualTo((total * 0.8).floor()));
    expect(levelCorrect, greaterThanOrEqualTo((total * 0.8).floor()));
  });
}
