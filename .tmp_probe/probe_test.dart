// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/models/protection_mode.dart';
import 'package:threatguard/core/services/threat_engine.dart';

void main() {
  final engine = ThreatEngine.instance;

  const cases = <String, String>{
    'bank alert':
        'Your HNB account ending 4821 was debited LKR 4,500.00 on '
        '20/10. If this was not you, call 0112 246 246 immediately.',
    'otp advice':
        'Never share your OTP or PIN with anyone. Your OTP is 448201. '
        'Do not share this code with anyone, including bank staff.',
    'delivery legit':
        'Your package from Daraz has been dispatched and will be '
        'delivered today between 2pm and 5pm. Track at daraz.lk/track/8842',
    'job offer legit':
        'Congratulations! You have been shortlisted for the '
        'interview for the Software Engineer position on Friday at 10am.',
    'security education':
        'Learn how phishing works: attackers send urgent '
        'messages asking you to verify your account and enter your password. '
        'Never do this. Report it to the bank.',
    'password reset self':
        'Use this link to reset your password: '
        'https://accounts.example.com/reset?t=abc',
    'true phishing':
        'Your account has been suspended due to unusual activity. '
        'Verify your password immediately at http://secure-verify-login.top '
        'to restore access.',
    'urgent refactor (benign)':
        'Today I pushed the login fix and updated the '
        'account settings page. Please review when you can.',
  };

  for (final entry in cases.entries) {
    for (final mode in ProtectionMode.values) {
      final r = engine.analyzeText(entry.value, mode: mode);
      final a = r.analysis;
      print(
        '${entry.key.padRight(26)} ${mode.name.padRight(9)} '
        '${a.finalType.name.padRight(18)} ${a.finalLevel.name.padRight(11)} '
        'score=${a.blendedRiskScore.toString().padLeft(3)} rule=${a.ruleAnalysis.riskScore.toString().padLeft(3)} '
        'src=${a.source.name.padRight(16)} conf=${(a.mlPrediction.confidence * 100).toStringAsFixed(0)}%',
      );
    }
  }

  print('--- evidence for bank alert ---');
  for (final i
      in engine
          .analyzeText(cases['bank alert']!)
          .analysis
          .ruleAnalysis
          .indicators) {
    print('  ${i.title} :: ${i.evidence}');
  }
  print('--- evidence for true phishing ---');
  for (final i
      in engine
          .analyzeText(cases['true phishing']!)
          .analysis
          .ruleAnalysis
          .indicators) {
    print('  ${i.title} :: ${i.evidence}');
  }
}
