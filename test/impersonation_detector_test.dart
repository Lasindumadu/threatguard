import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/services/impersonation_detector.dart';

void main() {
  const detector = ImpersonationDetector(
    officialDomains: [
      'paypal.com',
      'google.com',
      'microsoft.com',
      'amazon.com',
      'apple.com',
      'hnb.lk',
      'gov.lk',
    ],
  );

  group('never flags the genuine domain', () {
    // This is the invariant that matters most: a false impersonation warning on
    // a real bank domain teaches users to ignore the warnings.
    const genuine = [
      'paypal.com',
      'google.com',
      'microsoft.com',
      'amazon.com',
      'apple.com',
      'www.amazon.com',
      'www.google.com',
      'accounts.google.com',
      'login.microsoft.com',
      'www.amazon.com',
      'hnb.lk',
      'www.hnb.lk',
      'online.hnb.lk',
    ];

    for (final host in genuine) {
      test('"$host" is genuine', () {
        final result = detector.check(host);
        expect(
          result.verdict,
          ImpersonationVerdict.genuine,
          reason: '$host is an official domain and must never be flagged',
        );
        expect(result.riskContribution, 0);
      });
    }
  });

  group('detects likely impersonation', () {
    test('capital-I lookalike: paypaI.com', () {
      final result = detector.check('paypaI.com');
      expect(result.verdict, ImpersonationVerdict.likelyImpersonation);
      expect(result.brand, 'Paypal');
      expect(result.riskContribution, greaterThan(0));
    });

    test('leetspeak: g00gle.com', () {
      final result = detector.check('g00gle.com');
      expect(result.verdict, ImpersonationVerdict.likelyImpersonation);
      expect(result.brand, 'Google');
    });

    test('leetspeak: amaz0n.com', () {
      final result = detector.check('amaz0n.com');
      expect(result.verdict, ImpersonationVerdict.likelyImpersonation);
    });

    test('typosquat: goggle.com (1 edit from google)', () {
      final result = detector.check('goggle.com');
      expect(result.verdict, ImpersonationVerdict.likelyImpersonation);
      expect(result.brand, 'Google');
    });

    test('typosquat: arnazon.com', () {
      final result = detector.check('arnazon.com');
      expect(result.isConcerning, isTrue);
    });

    test('Cyrillic homoglyph: аpple.com uses U+0430', () {
      // "аpple.com" with a Cyrillic а, not a Latin a.
      final result = detector.check('\u0430pple.com');
      expect(result.isConcerning, isTrue);
      expect(result.brand, 'Apple');
    });
  });

  group('detects combosquatting and lure suffixes', () {
    test('paypal-verify.top', () {
      final result = detector.check('paypal-verify.top');
      expect(result.isConcerning, isTrue);
      expect(result.brand, 'Paypal');
      expect(result.reasons, isNotEmpty);
    });

    test('google-security.top', () {
      final result = detector.check('google-security.top');
      expect(result.isConcerning, isTrue);
    });

    test('microsoft-support.click', () {
      final result = detector.check('microsoft-support.click');
      expect(result.isConcerning, isTrue);
    });

    test('amazon-account-update.xyz', () {
      final result = detector.check('amazon-account-update.xyz');
      expect(result.isConcerning, isTrue);
    });
  });

  group('does not raise false alarms on unrelated sites', () {
    const unrelated = [
      'wikipedia.org',
      'github.com',
      'bbc.co.uk',
      'stackoverflow.com',
      'example.com',
      'dhl.com',
      'fedoraproject.org',
    ];

    for (final host in unrelated) {
      test('"$host" is not flagged', () {
        final result = detector.check(host);
        expect(
          result.isConcerning,
          isFalse,
          reason: '$host has no relation to the protected brands',
        );
      });
    }
  });

  group('host normalisation', () {
    test('strips scheme, path and port', () {
      expect(
        ImpersonationDetector.normalizeHost(
          'https://paypal.com:8443/login?x=1',
        ),
        'paypal.com',
      );
    });

    test('strips a leading www', () {
      expect(
        ImpersonationDetector.normalizeHost('www.google.com'),
        'google.com',
      );
    });

    test('lower-cases', () {
      expect(ImpersonationDetector.normalizeHost('PAYPAL.COM'), 'paypal.com');
    });

    test('handles multi-part suffixes like co.uk', () {
      // amazon.co.uk is not in the configured official list, so it is not
      // reported as "genuine" — but the important behaviour is that it is NOT
      // flagged as an impersonation either. `co.uk` must be treated as a public
      // suffix, so the base name is `amazon`, not `co`.
      final result = detector.check('amazon.co.uk');
      expect(result.isConcerning, isFalse);
      expect(
        result.verdict,
        isNot(ImpersonationVerdict.likelyImpersonation),
        reason: 'the genuine amazon.co.uk must never be called a lookalike',
      );
    });
  });

  group('levenshtein', () {
    test('identical strings are distance 0', () {
      expect(ImpersonationDetector.levenshtein('google', 'google'), 0);
    });

    test('single substitution is distance 1', () {
      expect(ImpersonationDetector.levenshtein('google', 'goggle'), 1);
    });

    test('handles empty strings', () {
      expect(ImpersonationDetector.levenshtein('', 'abc'), 3);
      expect(ImpersonationDetector.levenshtein('abc', ''), 3);
    });
  });

  group('short brand names are still protected', () {
    // A length guard applied to every check once hid these entirely: a 3-letter
    // bank abbreviation plus a lure suffix scored 14/100 and was reported as
    // safe. Edit distance is meaningless for short names, but combosquatting
    // and lure suffixes are not.
    const shortBrand = ImpersonationDetector(officialDomains: ['hnb.lk']);

    test('hnb-secure-login.top is flagged', () {
      final result = shortBrand.check('hnb-secure-login.top');
      expect(result.isConcerning, isTrue);
      expect(result.brand, 'Hnb');
    });

    test('hnb-verify.top is flagged', () {
      expect(shortBrand.check('hnb-verify.top').isConcerning, isTrue);
    });

    test('hnb-support.click is flagged', () {
      expect(shortBrand.check('hnb-support.click').isConcerning, isTrue);
    });

    test('the genuine hnb.lk is still genuine', () {
      expect(shortBrand.check('hnb.lk').verdict, ImpersonationVerdict.genuine);
    });

    test('an unrelated domain merely containing the letters is NOT flagged', () {
      // "hnboats.com" contains "hnb" as a substring but not as a token. Firing
      // here would be a false accusation against an innocent site.
      expect(shortBrand.check('hnboats.com').isConcerning, isFalse);
    });

    test('a domain that merely starts with the brand is not flagged', () {
      expect(shortBrand.check('hnbholding.lk').isConcerning, isFalse);
    });
  });

  group('empty official domain list', () {
    test('never reports impersonation when there is nothing to compare', () {
      const empty = ImpersonationDetector(officialDomains: []);
      final result = empty.check('paypal-verify.top');
      expect(result.isConcerning, isFalse);
    });
  });
}
