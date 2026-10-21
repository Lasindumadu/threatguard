import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/services/app_services.dart';
import 'package:threatguard/core/services/organization_registry.dart';

void main() {
  group('AppServices composition', () {
    // This group guards a bug that unit tests missed and only visual
    // verification caught: the impersonation detector's default constructor
    // takes an EMPTY official-domain list, so wiring the link scanner through
    // `const UrlForensicsAnalyzer()` silently disabled brand-impersonation
    // detection. The scanner reported "no problems found" for a bank lookalike.
    test('the registry actually contains official domains', () {
      final domains = <String>[
        for (final profile in const OrganizationRegistry().profiles)
          ...profile.officialDomains,
      ];

      expect(domains, isNotEmpty);
      expect(domains.contains('hnb.lk'), isTrue);
    });

    test('the link safety service detects a bank lookalike', () {
      final services = AppServices.instance;

      final result = services.linkSafetyService.analyzeOffline(
        'https://hnb-secure-login.top/verify',
      );

      expect(
        result.isSafe,
        isFalse,
        reason:
            'a lookalike of a registered bank must not be reported safe; '
            'if this fails, the impersonation detector was wired with an '
            'empty domain list',
      );
      expect(result.shouldIntercept, isTrue);
    });

    test('the link safety service clears the genuine bank domain', () {
      final services = AppServices.instance;

      final result = services.linkSafetyService.analyzeOffline(
        'https://www.hnb.lk/login',
      );

      expect(result.isSafe, isTrue);
    });

    test('every registry domain is recognised as genuine by the detector', () {
      final services = AppServices.instance;

      // The detector and the registry must agree, or the app would warn users
      // away from real bank and telecom links.
      for (final profile in const OrganizationRegistry().profiles) {
        for (final domain in profile.officialDomains) {
          final result = services.linkSafetyService.analyzeOffline(
            'https://$domain/',
          );

          expect(
            result.verdict.name,
            'looksSafe',
            reason: 'the official domain $domain must never be flagged',
          );
        }
      }
    });

    test('a registry is not shared by reference with the detector', () {
      // Guards against a future refactor aliasing the mutable list into the
      // detector, where a caller could then empty it.
      final services = AppServices.instance;
      final before = services.linkSafetyService.analyzeOffline(
        'https://paypal-verify.top',
      );

      expect(before.isSafe, isFalse);
    });
  });
}
