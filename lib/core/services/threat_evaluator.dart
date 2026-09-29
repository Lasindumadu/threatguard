import '../models/evaluation_case.dart';
import '../models/threat_analysis.dart';
import 'threat_analyzer.dart';

class EvaluationResult {
  final EvaluationCase testCase;
  final ThreatAnalysis actualAnalysis;

  const EvaluationResult({
    required this.testCase,
    required this.actualAnalysis,
  });

  bool get typeCorrect => testCase.expectedType == actualAnalysis.type;

  bool get levelCorrect => testCase.expectedLevel == actualAnalysis.level;

  bool get completelyCorrect => typeCorrect && levelCorrect;
}

class ThreatEvaluationReport {
  final List<EvaluationResult> results;

  const ThreatEvaluationReport({required this.results});

  int get totalCases => results.length;

  int get correctTypes => results.where((result) => result.typeCorrect).length;

  int get correctLevels =>
      results.where((result) => result.levelCorrect).length;

  int get completelyCorrect =>
      results.where((result) => result.completelyCorrect).length;

  double get typeAccuracy => totalCases == 0 ? 0 : correctTypes / totalCases;

  double get levelAccuracy => totalCases == 0 ? 0 : correctLevels / totalCases;

  double get overallAccuracy =>
      totalCases == 0 ? 0 : completelyCorrect / totalCases;
}

class ThreatEvaluator {
  final ThreatAnalyzer analyzer;

  const ThreatEvaluator({this.analyzer = const ThreatAnalyzer()});

  ThreatEvaluationReport evaluate(List<EvaluationCase> cases) {
    final results = cases.map((testCase) {
      final analysis = analyzer.analyze(testCase.message);

      return EvaluationResult(testCase: testCase, actualAnalysis: analysis);
    }).toList();

    return ThreatEvaluationReport(results: List.unmodifiable(results));
  }
}
