import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/services/ml_feature_extractor.dart';

void main() {
  group('MlFeatureExtractor', () {
    const extractor = MlFeatureExtractor();

    test('extracts phishing-related features correctly', () {
      final features = extractor.extract(
        caseId: 'test_phishing_001',
        message:
            'Your account has been suspended. '
            'Verify your account immediately at '
            'http://192.168.1.10/login.',
      );

      expect(features.caseId, 'test_phishing_001');

      expect(features.messageLength, greaterThan(0));
      expect(features.wordCount, greaterThan(0));
      expect(features.urlCount, 1);

      expect(features.hasUrgency, isTrue);
      expect(features.hasAccountSecurity, isTrue);
      expect(features.hasUrl, isTrue);

      expect(features.hasAccountVerification, isTrue);

      expect(features.hasIpUrl, isTrue);
      expect(features.hasSuspiciousUrl, isTrue);
    });

    test('extracts scam-related features correctly', () {
      final features = extractor.extract(
        caseId: 'test_scam_001',
        message:
            'Congratulations! You won a cash prize. '
            'Pay the required fee here: https://bit.ly/reward123.',
      );

      expect(features.caseId, 'test_scam_001');

      expect(features.hasPrizeReward, isTrue);
      expect(features.hasFinancial, isTrue);
      expect(features.hasUrl, isTrue);

      expect(features.hasShortenerUrl, isTrue);
      expect(features.hasSuspiciousUrl, isTrue);
    });

    test('extracts credential request features correctly', () {
      final features = extractor.extract(
        caseId: 'test_credential_001',
        message:
            'This is the bank security team. '
            'Send your verification code immediately.',
      );

      expect(features.hasAuthority, isTrue);
      expect(features.hasCredential, isTrue);
      expect(features.hasUrgency, isTrue);

      expect(features.hasCredentialRequest, isTrue);
      expect(features.hasStrongCredentialRequest, isTrue);
    });

    test('does not mark a normal message as suspicious URL', () {
      final features = extractor.extract(
        caseId: 'test_legitimate_001',
        message:
            'The office network server is available at '
            'http://192.168.1.50/status.',
      );

      expect(features.hasUrl, isTrue);
      expect(features.hasIpUrl, isTrue);

      // An IP address is structurally unusual, but the extractor
      // records the feature without deciding that the message is a threat.
      expect(features.hasSuspiciousUrl, isTrue);

      expect(features.hasUrgency, isFalse);
      expect(features.hasCredentialRequest, isFalse);
    });

    test('handles a plain legitimate message', () {
      final features = extractor.extract(
        caseId: 'test_legitimate_002',
        message: 'The meeting starts at 10 AM tomorrow.',
      );

      expect(features.caseId, 'test_legitimate_002');

      expect(features.urlCount, 0);
      expect(features.hasUrl, isFalse);
      expect(features.hasSuspiciousUrl, isFalse);

      expect(features.hasUrgency, isFalse);
      expect(features.hasCredentialRequest, isFalse);
      expect(features.hasStrongCredentialRequest, isFalse);
    });
  });
}
