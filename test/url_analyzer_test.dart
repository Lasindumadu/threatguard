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

    test('extracts domain from .co.uk hostname', () {
      final result = analyzer.analyze('https://login.example.co.uk/account');

      expect(result.host, 'login.example.co.uk');
      expect(result.domain, 'example.co.uk');
    });

    test('extracts domain from .gov.lk hostname', () {
      final result = analyzer.analyze('https://secure.example.gov.lk/login');

      expect(result.host, 'secure.example.gov.lk');
      expect(result.domain, 'example.gov.lk');
    });

    test('extracts domain from .co.lk hostname', () {
      final result = analyzer.analyze('https://shop.example.co.lk/login');

      expect(result.host, 'shop.example.co.lk');
      expect(result.domain, 'example.co.lk');
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

    test('detects valid IPv4 address hostname', () {
      final result = analyzer.analyze('http://8.8.8.8/login');

      expect(
        result.signals.any(
          (signal) => signal.type == UrlSignalType.ipAddressHost,
        ),
        isTrue,
      );
    });

    test('does not treat invalid IPv4 address as IP hostname', () {
      final result = analyzer.analyze('http://999.999.999.999/login');

      expect(
        result.signals.any(
          (signal) => signal.type == UrlSignalType.ipAddressHost,
        ),
        isFalse,
      );
    });

    test('does not treat out-of-range IPv4 octet as valid', () {
      final result = analyzer.analyze('http://192.168.1.999/login');

      expect(
        result.signals.any(
          (signal) => signal.type == UrlSignalType.ipAddressHost,
        ),
        isFalse,
      );
    });

    test('does not treat incomplete IPv4 address as valid', () {
      final result = analyzer.analyze('http://192.168.1/login');

      expect(
        result.signals.any(
          (signal) => signal.type == UrlSignalType.ipAddressHost,
        ),
        isFalse,
      );
    });

    test('detects a valid IPv6 address as a hostname', () {
      final result = analyzer.analyze('https://[2001:db8::1]/login');

      expect(
        result.signals.any(
          (signal) => signal.type == UrlSignalType.ipAddressHost,
        ),
        isTrue,
      );
    });

    test('detects a full valid IPv6 address as a hostname', () {
      final result = analyzer.analyze(
        'https://[2001:0db8:0000:0000:0000:ff00:0042:8329]/login',
      );

      expect(
        result.signals.any(
          (signal) => signal.type == UrlSignalType.ipAddressHost,
        ),
        isTrue,
      );
    });

    test('does not treat an invalid IPv6 address as an IP hostname', () {
      final result = analyzer.analyze('https://[2001:db8:xyz::1]/login');

      expect(
        result.signals.any(
          (signal) => signal.type == UrlSignalType.ipAddressHost,
        ),
        isFalse,
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

    test('detects Unicode internationalized hostname', () {
      final result = analyzer.analyze('https://münich.example/login');

      expect(result.host, isNotEmpty);
      expect(result.domain, isNotNull);
    });

    test('detects mixed-script Unicode hostname', () {
      final result = analyzer.analyze('https://раураl.example/login');

      expect(
        result.signals.any(
          (signal) => signal.type == UrlSignalType.mixedScriptHost,
        ),
        isTrue,
      );
    });

    test('does not flag a normal Unicode hostname as mixed-script', () {
      final result = analyzer.analyze('https://münich.example/login');

      expect(
        result.signals.any(
          (signal) => signal.type == UrlSignalType.mixedScriptHost,
        ),
        isFalse,
      );
    });

    test('detects Greek and Latin mixed-script hostname', () {
      final result = analyzer.analyze('https://paypaλ.example/login');

      expect(
        result.signals.any(
          (signal) => signal.type == UrlSignalType.mixedScriptHost,
        ),
        isTrue,
      );
    });

    test('Punycode hostname remains detectable', () {
      final result = analyzer.analyze('https://xn--80ak6aa92e.com/login');

      expect(
        result.signals.any(
          (signal) => signal.type == UrlSignalType.punycodeHost,
        ),
        isTrue,
      );
    });

    test('does not flag mixed scripts found only in query parameters', () {
      final result = analyzer.analyze(
        'https://example.com?next=paypaλ.example',
      );

      expect(
        result.signals.any(
          (signal) => signal.type == UrlSignalType.mixedScriptHost,
        ),
        isFalse,
      );
    });

    test('does not flag mixed scripts found only in URL fragments', () {
      final result = analyzer.analyze('https://example.com#paypaλ.example');

      expect(
        result.signals.any(
          (signal) => signal.type == UrlSignalType.mixedScriptHost,
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
