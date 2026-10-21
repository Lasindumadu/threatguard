import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/services/url_extractor.dart';

void main() {
  group('UrlExtractor', () {
    test('extracts scheme-prefixed URLs', () {
      expect(UrlExtractor.extract('Visit https://example.com now'), [
        'https://example.com',
      ]);
    });

    test('extracts bare domains', () {
      expect(UrlExtractor.extract('Go to example.com/page?a=1'), [
        'example.com/page?a=1',
      ]);
    });

    test('extracts www-prefixed URLs', () {
      expect(UrlExtractor.extract('see www.example.com'), ['www.example.com']);
    });

    test('does not treat e-mail addresses as URLs', () {
      expect(UrlExtractor.extract('write to me@example.com please'), isEmpty);
    });

    test('strips trailing sentence punctuation', () {
      expect(UrlExtractor.extract('Click https://bad.example.com/xyz.'), [
        'https://bad.example.com/xyz',
      ]);
    });

    test('finds multiple URLs and de-duplicates', () {
      final urls = UrlExtractor.extract(
        'a.com and https://b.com and a.com again',
      );
      expect(urls, ['a.com', 'https://b.com']);
    });

    test('agrees on bare and scheme hosts', () {
      final bare = UrlExtractor.extract('log into hnb.lk to verify');
      final scheme = UrlExtractor.extract('log into https://hnb.lk to verify');

      expect(bare.length, 1);
      expect(scheme.length, 1);
      expect(bare.first.endsWith('hnb.lk'), isTrue);
      expect(scheme.first.endsWith('hnb.lk'), isTrue);
    });

    test('ignores decimals and file-like tokens', () {
      expect(UrlExtractor.extract('we shipped 3.5 units'), isEmpty);
    });
  });
}
