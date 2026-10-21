// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/services/evaluation_dataset.dart';
import 'package:threatguard/core/services/threat_analyzer.dart';
void main() {
  const a = ThreatAnalyzer();
  for (final c in EvaluationDataset.cases) {
    if (['social_018','social_020','phishing_004','phishing_010','phishing_018'].contains(c.id)) {
      final r = a.analyze(c.message);
      print('${c.id} [${c.expectedType.name}/${c.expectedLevel.name}] got ${r.type.name}/${r.level.name} ${r.riskScore} :: ${c.message}');
    }
  }
}
