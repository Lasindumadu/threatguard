import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/sender_analysis.dart';
import 'package:threatguard/core/services/sender_analyzer.dart';

void main() {
  const analyzer = SenderAnalyzer();

  test('recognizes known HNB sender identity', () {
    final result = analyzer.analyze('HNBPROMO');

    expect(result.rawSender, 'HNBPROMO');
    expect(result.normalizedSender, 'hnbpromo');
    expect(result.senderType, SenderType.alphanumeric);
    expect(result.organization, 'Hatton National Bank');
    expect(result.verificationStatus, SenderVerificationStatus.recognized);
    expect(result.confidence, 0.85);
  });

  test('recognizes known SLT-MOBITEL sender identity', () {
    final result = analyzer.analyze('SLT-Mobitel');

    expect(result.organization, 'SLT-MOBITEL');
    expect(result.verificationStatus, SenderVerificationStatus.recognized);
  });

  test('does not assume Free Calls belongs to Hutch', () {
    final result = analyzer.analyze('Free Calls');

    expect(result.organization, isNull);
    expect(result.verificationStatus, SenderVerificationStatus.unknown);
    expect(result.confidence, 0.0);
  });

  test('recognizes phone number sender', () {
    final result = analyzer.analyze('+94771234567');

    expect(result.senderType, SenderType.phoneNumber);
    expect(result.organization, isNull);
    expect(result.verificationStatus, SenderVerificationStatus.unknown);
  });

  test('recognizes short code sender', () {
    final result = analyzer.analyze('1234');

    expect(result.senderType, SenderType.shortCode);
    expect(result.organization, isNull);
    expect(result.verificationStatus, SenderVerificationStatus.unknown);
  });

  test('handles empty sender', () {
    final result = analyzer.analyze(null);

    expect(result.senderType, SenderType.unknown);
    expect(result.organization, isNull);
    expect(result.verificationStatus, SenderVerificationStatus.unknown);
    expect(result.confidence, 0.0);
  });

  test('normalizes sender without changing the original value', () {
    final result = analyzer.analyze('  HNBPROMO  ');

    expect(result.rawSender, 'HNBPROMO');
    expect(result.normalizedSender, 'hnbpromo');
    expect(result.organization, 'Hatton National Bank');
  });
}
