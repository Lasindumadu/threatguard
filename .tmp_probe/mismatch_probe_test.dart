// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/services/evaluation_dataset.dart';
import 'package:threatguard/core/services/threat_analyzer.dart';
void main() {
  const a = ThreatAnalyzer();
  for (final c in EvaluationDataset.cases) {
    final ids = ['spam_001','spam_004','spam_006','spam_007','spam_009','spam_011','spam_014','phishing_004','phishing_010','scam_005','social_004','social_013'];
    if (!ids.contains(c.id)) continue;
    final r = a.analyze(c.message);
    print('### ${c.id} got=${r.type.name}/${r.level.name}/${r.riskScore}');
    print('    MSG ${c.message}');
    print('    IND ${r.indicators.where((i)=>i.scoreContribution>0).map((i)=>i.title).join(' | ')}');
  }
}
