// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/models/message_source.dart';
import 'package:threatguard/core/services/threat_engine.dart';

void main() {
  final e = ThreatEngine.instance;
  for (final body in [
    'Your account is suspended. Verify your password immediately.',
    'Your account is suspended. Verify your password immediately at http://evil-EVIL.top/login',
  ]) {
    final r = e.analyzeText(body, source: MessageSource.sms);
    print('INPUT: $body');
    print('  rule=${r.analysis.ruleAnalysis.type.name}/${r.analysis.ruleAnalysis.level.name} '
        'final=${r.analysis.finalType.name}/${r.analysis.finalLevel.name}');
    for (final i in r.analysis.ruleAnalysis.indicators) {
      print('   - ${i.title} :: ${i.evidence}');
    }
  }
}
