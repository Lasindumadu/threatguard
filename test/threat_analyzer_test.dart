import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/threat_analysis.dart';
import 'package:threatguard/core/services/threat_analyzer.dart';

void main() {
  const analyzer = ThreatAnalyzer();

  group('ThreatAnalyzer basic behavior', () {
    test('empty message is safe', () {
      final result = analyzer.analyze('');

      expect(result.riskScore, 0);
      expect(result.level, ThreatLevel.safe);
      expect(result.type, ThreatType.legitimate);
      expect(result.detectedUrls, isEmpty);
      expect(result.indicators, isEmpty);
    });

    test('normal legitimate message is safe', () {
      final result = analyzer.analyze(
        'Hi, the meeting is scheduled for tomorrow at 10 AM.',
      );

      expect(result.level, ThreatLevel.safe);
      expect(result.type, ThreatType.legitimate);
    });

    test('promotional message is classified as spam', () {
      final result = analyzer.analyze(
        'Special offer today. Get 50% off selected products.',
      );

      expect(result.level, ThreatLevel.suspicious);
      expect(result.type, ThreatType.spam);
    });

    test('credential request is classified as phishing', () {
      final result = analyzer.analyze(
        'Please enter your password to verify your account.',
      );

      expect(result.type, ThreatType.phishing);
      expect(result.level, ThreatLevel.highRisk);
    });

    test('prize with financial request is classified as scam', () {
      final result = analyzer.analyze(
        'Congratulations! You won a cash prize. '
        'Pay the processing fee to claim it.',
      );

      expect(result.type, ThreatType.scam);
      expect(result.level, ThreatLevel.suspicious);
    });

    test(
      'authority plus urgency plus credential request is social engineering',
      () {
        final result = analyzer.analyze(
          'This is customer support. '
          'Send your security code immediately.',
        );

        expect(result.type, ThreatType.socialEngineering);
        expect(result.level, ThreatLevel.suspicious);
      },
    );
  });

  group('ThreatAnalyzer URL detection', () {
    test('detects a single URL', () {
      final result = analyzer.analyze(
        'Please visit https://example.com to continue.',
      );

      expect(result.detectedUrls, ['https://example.com']);
    });

    test('detects multiple URLs', () {
      final result = analyzer.analyze(
        'Visit https://example.com or https://example.org now.',
      );

      expect(result.detectedUrls, [
        'https://example.com',
        'https://example.org',
      ]);
    });

    test('detects www URLs', () {
      final result = analyzer.analyze(
        'Visit www.example.com for more information.',
      );

      expect(result.detectedUrls, ['www.example.com']);
    });
    test('detects a bare domain URL', () {
      final result = analyzer.analyze('Please visit example.com to continue.');

      expect(result.detectedUrls, ['example.com']);
    });

    test('detects a bare domain with a path', () {
      final result = analyzer.analyze(
        'Verify your account at secure.example.com/login now.',
      );

      expect(result.detectedUrls, ['secure.example.com/login']);
    });

    test('detects a bare Sri Lankan domain with a path', () {
      final result = analyzer.analyze(
        'Visit secure.example.gov.lk/login to continue.',
      );

      expect(result.detectedUrls, ['secure.example.gov.lk/login']);
    });
  });

  group('ThreatAnalyzer contextual behavior', () {
    test('credential request with urgency increases risk', () {
      final result = analyzer.analyze(
        'Enter your verification code immediately.',
      );

      expect(result.type, ThreatType.phishing);
      expect(result.riskScore, greaterThanOrEqualTo(25));
    });

    test('PIN request is recognized as a credential request', () {
      final result = analyzer.analyze('Please enter your PIN to continue.');

      expect(result.type, ThreatType.phishing);
      expect(result.level, ThreatLevel.suspicious);
    });

    test('security code request is recognized as a credential request', () {
      final result = analyzer.analyze('Please provide your security code.');

      expect(result.type, ThreatType.phishing);
      expect(result.level, ThreatLevel.suspicious);
    });

    test('urgent account verification with URL is classified as phishing', () {
      final result = analyzer.analyze(
        'Verify your account immediately at https://bit.ly/verify123.',
      );

      expect(result.type, ThreatType.phishing);
      expect(result.level, ThreatLevel.highRisk);
    });

    test('urgent account verification without URL remains suspicious', () {
      final result = analyzer.analyze(
        'Please verify your account immediately.',
      );

      expect(result.level, ThreatLevel.suspicious);
    });

    test('account verification with ordinary URL remains suspicious', () {
      final result = analyzer.analyze(
        'Please verify your account at https://example.com/account.',
      );

      expect(result.level, ThreatLevel.suspicious);
    });
  });

  group('ThreatAnalyzer URL integration', () {
    test('URL structural signal appears in main analysis', () {
      final result = analyzer.analyze(
        'Please visit http://192.168.1.10/login.',
      );

      expect(result.detectedUrls, ['http://192.168.1.10/login']);

      expect(
        result.indicators.any(
          (indicator) => indicator.title == 'IP address used as hostname',
        ),
        isTrue,
      );
    });

    test('URL shortener signal appears in main analysis', () {
      final result = analyzer.analyze('Please open https://bit.ly/abc123.');

      expect(
        result.indicators.any(
          (indicator) => indicator.title == 'URL shortener detected',
        ),
        isTrue,
      );
    });

    test('URL structural signals do not add score yet', () {
      final result = analyzer.analyze('Visit https://192.168.1.10:8080/login.');

      /*
       * Structural URL signals are currently evidence-only.
       * They must contribute zero points individually.
       *
       * We intentionally do not assert the total risk score because
       * other existing rules and URL detection may contribute to it.
       */

      final ipSignal = result.indicators.firstWhere(
        (indicator) => indicator.title == 'IP address used as hostname',
      );

      final portSignal = result.indicators.firstWhere(
        (indicator) => indicator.title == 'Non-standard port',
      );

      expect(ipSignal.scoreContribution, 0);
      expect(portSignal.scoreContribution, 0);
    });

    test('ordinary URL does not create structural warning signals', () {
      final result = analyzer.analyze('Visit https://example.com/account.');

      expect(
        result.indicators.any(
          (indicator) => indicator.title == 'IP address used as hostname',
        ),
        isFalse,
      );

      expect(
        result.indicators.any(
          (indicator) => indicator.title == 'Punycode hostname',
        ),
        isFalse,
      );

      expect(
        result.indicators.any(
          (indicator) => indicator.title == 'Embedded user information',
        ),
        isFalse,
      );

      expect(
        result.indicators.any(
          (indicator) => indicator.title == 'Non-standard port',
        ),
        isFalse,
      );

      expect(
        result.indicators.any(
          (indicator) => indicator.title == 'Deep subdomain structure',
        ),
        isFalse,
      );

      expect(
        result.indicators.any(
          (indicator) => indicator.title == 'URL shortener detected',
        ),
        isFalse,
      );
    });
  });
}
