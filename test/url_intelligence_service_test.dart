import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/url_intelligence.dart';
import 'package:threatguard/core/models/url_reputation.dart';
import 'package:threatguard/core/services/composite_url_reputation_provider.dart';
import 'package:threatguard/core/services/local_url_reputation_provider.dart';
import 'package:threatguard/core/services/url_analyzer.dart';
import 'package:threatguard/core/services/url_intelligence_service.dart';

void main() {
  const reputationProvider = CompositeUrlReputationProvider(
    providers: [LocalUrlReputationProvider()],
  );

  const service = UrlIntelligenceService(
    urlAnalyzer: UrlAnalyzer(),
    reputationProvider: reputationProvider,
  );

  test('combines structural analysis and reputation for IP URL', () async {
    final result = await service.analyze('http://192.168.1.10/login');

    expect(result, isA<UrlIntelligence>());
    expect(result.url, 'http://192.168.1.10/login');

    expect(
      result.structuralAnalysis.signals.any(
        (signal) => signal.type.name == 'ipAddressHost',
      ),
      isTrue,
    );

    expect(result.reputation.status, UrlReputationStatus.suspicious);
  });

  test('combines structural analysis and reputation for shortener', () async {
    final result = await service.analyze('https://bit.ly/4yvMoRj');

    expect(result.url, 'https://bit.ly/4yvMoRj');

    expect(
      result.structuralAnalysis.signals.any(
        (signal) => signal.type.name == 'urlShortener',
      ),
      isTrue,
    );

    expect(result.reputation.status, UrlReputationStatus.suspicious);
  });

  test('returns valid reputation for normal HTTPS URL', () async {
    final result = await service.analyze('https://hnb.lk');

    expect(result.url, 'https://hnb.lk');

    expect(result.structuralAnalysis.host, 'hnb.lk');
    expect(result.reputation.status, UrlReputationStatus.valid);
  });

  test('returns invalid reputation for malformed URL', () async {
    final result = await service.analyze('not-a-valid-url');

    expect(result.url, 'not-a-valid-url');
    expect(result.reputation.status, UrlReputationStatus.invalid);
  });
}
