// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/models/protection_mode.dart';
import 'package:threatguard/core/services/threat_analyzer.dart';

void main() {
  const a = ThreatAnalyzer();
  const samples = [
    'Your account has been locked. Unusual activity detected. Please review.',
    'We detected unusual activity. Please confirm your account details within 24 hours.',
    'Please verify your account details within 24 hours.',
    'Your statement is ready. Visit example.com to view it.',
    'Please review the login page today.',
    'Confirm your details within 24 hours by replying to this message.',
  ];

  for (final s in samples) {
    final line = StringBuffer();
    for (final m in ProtectionMode.values) {
      final r = a.analyze(s, mode: m);
      line.write('${m.name}=${r.riskScore}/${r.level.name}/${r.type.name}  ');
    }
    print('$line <= $s');
  }
}
