import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/url_reputation.dart';
import 'package:threatguard/core/services/impersonation_detector.dart';
import 'package:threatguard/core/services/link_safety_service.dart';
import 'package:threatguard/core/services/url_forensics_analyzer.dart';

void main() {
  const service = LinkSafetyService(
    forensicsAnalyzer: UrlForensicsAnalyzer(
      impersonationDetector: ImpersonationDetector(
        officialDomains: ['paypal.com', 'hnb.lk'],
      ),
    ),
  );

  group('offline verdicts', () {
    test('an ordinary https link is safe', () {
      final result = service.analyzeOffline('https://www.example.com/docs');
      expect(result.verdict, LinkSafetyGrade.looksSafe);
      expect(result.isSafe, isTrue);
      expect(result.shouldIntercept, isFalse);
    });

    test('the genuine bank domain is safe', () {
      final result = service.analyzeOffline('https://www.hnb.lk/login');
      expect(result.verdict, LinkSafetyGrade.looksSafe);
    });

    test('a lookalike brand domain is dangerous and should be intercepted', () {
      final result = service.analyzeOffline('https://paypal-verify.top/login');

      expect(result.verdict, LinkSafetyGrade.dangerous);
      expect(result.isDangerous, isTrue);
      expect(result.shouldIntercept, isTrue);
      expect(result.reasons, isNotEmpty);
    });

    test('a raw-IP login link is dangerous', () {
      final result = service.analyzeOffline('http://203.0.113.9/login');
      expect(result.isDangerous, isTrue);
    });

    test('reasons are human-readable sentences, not codes', () {
      final result = service.analyzeOffline('http://paypa1-secure.top/login');

      expect(result.reasons, isNotEmpty);
      for (final reason in result.reasons) {
        expect(reason.length, greaterThan(15));
        expect(reason, isNot(matches(RegExp(r'^[A-Z_]+$'))));
      }
    });

    test('headline and recommendation are always present', () {
      for (final url in [
        'https://example.com',
        'http://203.0.113.9/login',
        'https://paypal-verify.top',
      ]) {
        final result = service.analyzeOffline(url);
        expect(result.headline, isNotEmpty);
        expect(result.recommendation, isNotEmpty);
      }
    });
  });

  group('non-HTTP schemes are never openable', () {
    test('javascript: URI is not openable', () {
      final result = service.analyzeOffline('javascript:alert(1)');
      expect(result.isOpenableScheme, isFalse);
    });

    test('intent: URI is not openable', () {
      final result = service.analyzeOffline(
        'intent://scan/#Intent;scheme=zxing;end',
      );
      expect(result.isOpenableScheme, isFalse);
    });

    test('tg: URI is not openable', () {
      final result = service.analyzeOffline('tg://resolve?domain=evil');
      expect(result.isOpenableScheme, isFalse);
    });

    test('https is openable', () {
      expect(
        service.analyzeOffline('https://example.com').isOpenableScheme,
        isTrue,
      );
    });

    test('http is openable (the browser will still warn)', () {
      expect(
        service.analyzeOffline('http://example.com').isOpenableScheme,
        isTrue,
      );
    });
  });

  group('reputation can raise a verdict but never lower it', () {
    test('a malicious reputation forces a dangerous verdict', () {
      final result = service.combine(
        'https://example.com',
        const UrlReputation(
          url: 'https://example.com',
          status: UrlReputationStatus.malicious,
          reason: 'known phishing host',
        ),
      );

      expect(result.verdict, LinkSafetyGrade.dangerous);
      expect(result.score, 100);
      expect(
        result.reasons.any((r) => r.toLowerCase().contains('malicious')),
        isTrue,
      );
    });

    test('a suspicious reputation raises an otherwise-safe link', () {
      final result = service.combine(
        'https://example.com',
        const UrlReputation(
          url: 'https://example.com',
          status: UrlReputationStatus.suspicious,
        ),
      );

      expect(result.verdict, LinkSafetyGrade.suspicious);
      expect(result.shouldIntercept, isTrue);
    });

    test('a SAFE reputation cannot clear a dangerous offline verdict', () {
      // This is the important case: reputation services lag newly-registered
      // phishing domains, so a "clean" report must not override hard evidence.
      final result = service.combine(
        'https://paypal-verify.top/login',
        const UrlReputation(
          url: 'https://paypal-verify.top/login',
          status: UrlReputationStatus.safe,
        ),
      );

      expect(
        result.verdict,
        LinkSafetyGrade.dangerous,
        reason:
            'a clean reputation must never clear a brand-impersonating '
            'domain',
      );
    });

    test('an unknown reputation leaves the offline verdict untouched', () {
      final withoutReputation = service.analyzeOffline('https://example.com');
      final withUnknown = service.combine(
        'https://example.com',
        const UrlReputation(
          url: 'https://example.com',
          status: UrlReputationStatus.unknown,
        ),
      );

      expect(withUnknown.verdict, withoutReputation.verdict);
      expect(withUnknown.score, withoutReputation.score);
    });

    test('score never exceeds 100', () {
      final result = service.combine(
        'https://paypal-verify.top/a.b.c.d/x?y=1',
        const UrlReputation(url: 'x', status: UrlReputationStatus.malicious),
      );
      expect(result.score, lessThanOrEqualTo(100));
    });
  });

  group('QuarantineVault', () {
    test('stores and resolves by id', () {
      final vault = QuarantineVault();
      final safety = service.analyzeOffline('https://paypal-verify.top');

      final id = vault.quarantine(safety);

      expect(vault.size, 1);
      expect(vault.resolve(id), same(safety));
    });

    test('releasing removes the entry', () {
      final vault = QuarantineVault();
      final safety = service.analyzeOffline('https://example.com');
      final id = vault.quarantine(safety);

      expect(vault.release(id), same(safety));
      expect(vault.resolve(id), isNull);
      expect(vault.size, 0);
    });

    test('ids are unique', () {
      final vault = QuarantineVault();
      final safety = service.analyzeOffline('https://example.com');

      final ids = {
        vault.quarantine(safety),
        vault.quarantine(safety),
        vault.quarantine(safety),
      };

      expect(ids.length, 3);
    });

    test('resolving an unknown id returns null', () {
      expect(QuarantineVault().resolve('nope'), isNull);
    });

    test('clear empties the vault', () {
      final vault = QuarantineVault();
      vault.quarantine(service.analyzeOffline('https://example.com'));
      vault.clear();
      expect(vault.size, 0);
    });
  });
}
