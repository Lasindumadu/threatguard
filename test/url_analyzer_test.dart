import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/url_analysis.dart';
import 'package:threatguard/core/services/url_analyzer.dart';

void main() {
  const analyzer = UrlAnalyzer();

  group('UrlAnalyzer basic parsing', () {
    test('extracts host from HTTPS URL', () {
      final result = analyzer.analyze('https://example.com/account');

      expect(result.host, 'example.com');
      expect(result.domain, 'example.com');
      expect(result.signals, isEmpty);
    });

    test('extracts host from HTTP URL', () {
      final result = analyzer.analyze('http://example.com/login');

      expect(result.host, 'example.com');
      expect(result.domain, 'example.com');
      expect(result.signals, isEmpty);
    });

    test('extracts host from www URL', () {
      final result = analyzer.analyze('www.example.com/account');

      expect(result.host, 'www.example.com');
      expect(result.domain, 'example.com');
      expect(result.signals, isEmpty);
    });

    test('extracts domain from subdomain', () {
      final result = analyzer.analyze('https://login.example.com/account');

      expect(result.host, 'login.example.com');
      expect(result.domain, 'example.com');
      expect(result.signals, isEmpty);
    });

    test('normalizes host to lowercase', () {
      final result = analyzer.analyze('https://LOGIN.Example.COM/account');

      expect(result.host, 'login.example.com');
      expect(result.domain, 'example.com');
      expect(result.signals, isEmpty);
    });

    test('handles standard HTTPS port without a signal', () {
      final result = analyzer.analyze('https://example.com:443/login');

      expect(result.host, 'example.com');
      expect(result.domain, 'example.com');
      expect(result.signals, isEmpty);
    });

    test('handles non-standard port', () {
      final result = analyzer.analyze('https://example.com:8080/login');

      expect(result.host, 'example.com');
      expect(result.domain, 'example.com');

      expect(
        result.signals.any(
          (signal) => signal.type == UrlSignalType.nonStandardPort,
        ),
        isTrue,
      );
    });

    test('handles URL without path', () {
      final result = analyzer.analyze('https://example.com');

      expect(result.host, 'example.com');
      expect(result.domain, 'example.com');
      expect(result.signals, isEmpty);
    });
  });

  group('UrlAnalyzer structural signals', () {
    test('detects IP address hostname', () {
      final result = analyzer.analyze('http://192.168.1.10/login');

      expect(
        result.signals.any(
          (signal) => signal.type == UrlSignalType.ipAddressHost,
        ),
        isTrue,
      );
    });

    test('detects Punycode hostname', () {
      final result = analyzer.analyze('https://xn--example-9za.com/login');

      expect(
        result.signals.any(
          (signal) => signal.type == UrlSignalType.punycodeHost,
        ),
        isTrue,
      );
    });

    test('detects embedded user information', () {
      final result = analyzer.analyze('https://example.com@evil.example/login');

      expect(
        result.signals.any(
          (signal) => signal.type == UrlSignalType.embeddedCredentials,
        ),
        isTrue,
      );

      expect(result.host, 'evil.example');
    });

    test('detects deep subdomain structure', () {
      final result = analyzer.analyze('https://a.b.c.d.example.com/login');

      expect(
        result.signals.any(
          (signal) => signal.type == UrlSignalType.excessiveSubdomains,
        ),
        isTrue,
      );
    });

    test('does not flag normal subdomain structure', () {
      final result = analyzer.analyze('https://login.example.com/account');

      expect(
        result.signals.any(
          (signal) => signal.type == UrlSignalType.excessiveSubdomains,
        ),
        isFalse,
      );
    });

    test('detects known URL shortener', () {
      final result = analyzer.analyze('https://bit.ly/abc123');

      expect(
        result.signals.any(
          (signal) => signal.type == UrlSignalType.urlShortener,
        ),
        isTrue,
      );
    });

    test('does not flag ordinary domain as URL shortener', () {
      final result = analyzer.analyze('https://example.com/abc123');

      expect(
        result.signals.any(
          (signal) => signal.type == UrlSignalType.urlShortener,
        ),
        isFalse,
      );
    });
  });

  group('UrlAnalyzer multiple URLs', () {
    test('analyzes multiple URLs', () {
      final results = analyzer.analyzeAll([
        'https://example.com',
        'https://login.example.org/account',
        'http://192.168.1.10/login',
      ]);

      expect(results.length, 3);

      expect(results[0].host, 'example.com');
      expect(results[0].domain, 'example.com');
      expect(results[0].signals, isEmpty);

      expect(results[1].host, 'login.example.org');
      expect(results[1].domain, 'example.org');
      expect(results[1].signals, isEmpty);

      expect(results[2].host, '192.168.1.10');

      expect(
        results[2].signals.any(
          (signal) => signal.type == UrlSignalType.ipAddressHost,
        ),
        isTrue,
      );
    });
  });
}
