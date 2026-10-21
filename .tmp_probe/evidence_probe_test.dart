// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/services/threat_engine.dart';

void main() {
  final e = ThreatEngine.instance;
  const cases = {
    'otp advice':
        'Never share your OTP or PIN with anyone. Your OTP is 448201. '
        'Do not share this code with anyone, including bank staff.',
    'security education':
        'Learn how phishing works: attackers send urgent '
        'messages asking you to verify your account and enter your password. '
        'Never do this. Report it to the bank.',
    'job':
        'Congratulations! You have been shortlisted for the interview for '
        'the Software Engineer position on Friday at 10am.',
  };
  for (final entry in cases.entries) {
    final r = e.analyzeText(entry.value).analysis;
    print(
      '=== ${entry.key}: ${r.finalType.name}/${r.finalLevel.name} ${r.blendedRiskScore}',
    );
    print('    rationale: ${r.rationale}');
    for (final i in r.ruleAnalysis.indicators) {
      print('    ${i.scoreContribution} ${i.title} :: ${i.evidence}');
    }
  }
}
