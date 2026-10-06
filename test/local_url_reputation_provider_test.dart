import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/url_reputation.dart';
import 'package:threatguard/core/services/local_url_reputation_provider.dart';

void main() {
  const provider = LocalUrlReputationProvider();

  test('detects invalid URL', () async {
    final before = DateTime.now();

    final result = await provider.checkUrl('not-a-valid-url');

    final after = DateTime.now();

    expect(result.status, UrlReputationStatus.invalid);
    expect(result.reason, contains('could not be parsed'));
    expect(result.source, UrlReputationSource.local);
    expect(result.checkedAt, isNotNull);
    expect(
      result.checkedAt!.isAfter(before.subtract(const Duration(seconds: 1))),
      isTrue,
    );
    expect(
      result.checkedAt!.isBefore(after.add(const Duration(seconds: 1))),
      isTrue,
    );
  });

  test('detects IP address URL as suspicious', () async {
    final result = await provider.checkUrl('http://192.168.1.10/login');

    expect(result.status, UrlReputationStatus.suspicious);
    expect(result.reason, contains('IP address'));
    expect(result.source, UrlReputationSource.local);
    expect(result.checkedAt, isNotNull);
  });

  test('detects shortened URL as suspicious', () async {
    final result = await provider.checkUrl('https://bit.ly/4yvMoRj');

    expect(result.status, UrlReputationStatus.suspicious);
    expect(result.reason, contains('URL-shortening'));
    expect(result.source, UrlReputationSource.local);
    expect(result.checkedAt, isNotNull);
  });

  test('accepts normal HTTPS URL as structurally valid', () async {
    final result = await provider.checkUrl('https://hnb.lk');

    expect(result.status, UrlReputationStatus.valid);
    expect(result.reason, contains('structurally valid'));
    expect(result.source, UrlReputationSource.local);
    expect(result.checkedAt, isNotNull);
  });

  test('accepts normal HTTP URL as structurally valid', () async {
    final result = await provider.checkUrl('http://example.com');

    expect(result.status, UrlReputationStatus.valid);
    expect(result.source, UrlReputationSource.local);
    expect(result.checkedAt, isNotNull);
  });
}
