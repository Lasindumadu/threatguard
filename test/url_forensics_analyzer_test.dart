import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/services/impersonation_detector.dart';
import 'package:threatguard/core/services/url_forensics_analyzer.dart';

void main() {
  const analyzer = UrlForensicsAnalyzer(
    impersonationDetector: ImpersonationDetector(
      officialDomains: ['paypal.com', 'google.com', 'hnb.lk'],
    ),
  );

  group('host decomposition', () {
    test('simple domain', () {
      final f = analyzer.analyze('https://example.com/page');
      expect(f.host, 'example.com');
      expect(f.registrableDomain, 'example.com');
      expect(f.publicSuffix, 'com');
      expect(f.subdomain, isNull);
      expect(f.path, '/page');
      expect(f.isHttps, isTrue);
    });

    test('subdomain is separated from the registrable domain', () {
      final f = analyzer.analyze('https://mail.google.com/inbox');
      expect(f.host, 'mail.google.com');
      expect(f.registrableDomain, 'google.com');
      expect(f.subdomain, 'mail');
      expect(f.subdomainCount, 1);
    });

    test('deep subdomain chain is counted', () {
      final f = analyzer.analyze('https://a.b.c.d.evil.com/');
      expect(f.registrableDomain, 'evil.com');
      expect(f.subdomainCount, 4);
      expect(
        f.findings.any((x) => x.title.contains('Excessive subdomains')),
        isTrue,
      );
    });

    test('two-part suffix co.uk', () {
      final f = analyzer.analyze('https://www.bbc.co.uk/news');
      expect(f.registrableDomain, 'bbc.co.uk');
      expect(f.publicSuffix, 'co.uk');
      expect(f.subdomain, 'www');
    });

    test('two-part suffix com.au', () {
      final f = analyzer.analyze('https://shop.example.com.au');
      expect(f.registrableDomain, 'example.com.au');
      expect(f.publicSuffix, 'com.au');
      expect(f.subdomain, 'shop');
    });

    test('Sri Lankan gov.lk suffix', () {
      final f = analyzer.analyze('https://www.ird.gov.lk/');
      expect(f.registrableDomain, 'ird.gov.lk');
      expect(f.publicSuffix, 'gov.lk');
    });
  });

  group('flags real problems', () {
    test('plain HTTP is flagged and lowers confidence', () {
      final f = analyzer.analyze('http://example.com/login');
      expect(f.isHttps, isFalse);
      expect(f.findings.any((x) => x.title.contains('HTTP')), isTrue);
      expect(f.grade, isNot(LinkSafetyGrade.looksSafe));
    });

    test('raw IP host is flagged', () {
      final f = analyzer.analyze('http://192.168.1.1/login');
      expect(f.isIpHost, isTrue);
      expect(f.grade, LinkSafetyGrade.dangerous);
    });

    test('embedded credentials are critical', () {
      final f = analyzer.analyze('https://paypal.com@evil.top/login');
      expect(f.hasEmbeddedCredentials, isTrue);
      expect(f.host, 'evil.top');
      expect(f.grade, LinkSafetyGrade.dangerous);
      expect(
        f.findings.any((x) => x.severity == UrlFindingSeverity.critical),
        isTrue,
      );
    });

    test('non-standard port is noted', () {
      final f = analyzer.analyze('https://example.com:8443/');
      expect(f.port, 8443);
      expect(f.findings.any((x) => x.title.contains('port')), isTrue);
    });

    test('shortener is flagged', () {
      final f = analyzer.analyze('https://bit.ly/3xYzAbC');
      expect(f.isShortener, isTrue);
      expect(f.findings.any((x) => x.title == 'Link shortener'), isTrue);
    });

    test('high-abuse TLD is flagged', () {
      final f = analyzer.analyze('http://claim-prize.top/');
      expect(f.findings.any((x) => x.title.contains('High-abuse')), isTrue);
    });

    test('lookalike brand domain is dangerous', () {
      final f = analyzer.analyze('https://paypal-verify.top/login');
      expect(f.impersonation, isNotNull);
      expect(f.impersonation!.isConcerning, isTrue);
      expect(f.grade, LinkSafetyGrade.dangerous);
    });
  });

  group('does not cry wolf on ordinary links', () {
    test('a normal https link looks safe', () {
      final f = analyzer.analyze('https://www.example.com/articles/security');
      expect(f.grade, LinkSafetyGrade.looksSafe);
      expect(f.riskScore, lessThan(20));
      expect(f.isConcerning, isFalse);
    });

    test('the genuine bank domain is safe', () {
      final f = analyzer.analyze('https://www.hnb.lk/');
      expect(f.grade, LinkSafetyGrade.looksSafe);
      expect(f.impersonation!.verdict, ImpersonationVerdict.genuine);
    });

    test('a genuine subdomain is safe', () {
      final f = analyzer.analyze('https://online.hnb.lk/login');
      expect(f.grade, LinkSafetyGrade.looksSafe);
    });

    test('a standard port is not noted', () {
      final f = analyzer.analyze('https://example.com:443/');
      expect(f.findings.any((x) => x.title.contains('port')), isFalse);
    });
  });

  group('unparseable input', () {
    test('plain prose is reported as not a URL', () {
      final f = analyzer.analyze('this is not a url at all');
      expect(f.findings.first.title, 'Not a valid URL');
      expect(f.riskScore, 0);
    });

    test('empty string does not crash', () {
      final f = analyzer.analyze('   ');
      expect(f.host, '');
      expect(f.grade, LinkSafetyGrade.looksSafe);
    });
  });

  group('risk scoring', () {
    test('score is clamped to 100', () {
      final f = analyzer.analyze(
        'http://user:pass@192.168.0.1:8080/a.b.c.d.paypal-secure.top/login',
      );
      expect(f.riskScore, lessThanOrEqualTo(100));
      expect(f.riskScore, greaterThan(50));
    });

    test(
      'displayAddress shows the registrable domain, not the subdomain chain',
      () {
        final f = analyzer.analyze('https://login.secure.bank.evil.com/path');
        expect(f.displayAddress.startsWith('evil.com'), isTrue);
      },
    );
  });
}
