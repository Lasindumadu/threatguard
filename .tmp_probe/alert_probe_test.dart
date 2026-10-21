// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/models/message_source.dart';
import 'package:threatguard/core/models/protection_mode.dart';
import 'package:threatguard/core/models/threat_message.dart';
import 'package:threatguard/core/services/threat_engine.dart';

void main() {
  final r = ThreatEngine.instance.analyzeMessage(
    const ThreatMessage(
      id: 'x',
      body: 'Your account is suspended. Verify your password immediately '
          'at http://evil-EVIL.top/login',
      sender: 'EVIL',
      source: MessageSource.sms,
    ),
    mode: ProtectionMode.strict,
  );
  print('final=${r.analysis.finalType.name}/${r.analysis.finalLevel.name} '
      'rule=${r.analysis.ruleAnalysis.type.name}/${r.analysis.ruleAnalysis.level.name} '
      'src=${r.analysis.source.name} score=${r.analysis.blendedRiskScore}');
  print('rationale=${r.analysis.rationale}');
  for (final i in r.analysis.ruleAnalysis.indicators) {
    print('  ${i.title} | ${i.evidence} | ${i.scoreContribution}');
  }
}
