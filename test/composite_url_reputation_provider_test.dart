import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/url_reputation.dart';
import 'package:threatguard/core/services/composite_url_reputation_provider.dart';
import 'package:threatguard/core/services/url_reputation_provider.dart';
import 'package:threatguard/core/services/unavailable_online_url_reputation_provider.dart';

class FixedUrlReputationProvider extends UrlReputationProvider {
  final UrlReputation result;

  const FixedUrlReputationProvider(this.result);

  @override
  Future<UrlReputation> checkUrl(String url) async {
    return UrlReputation(
      url: url,
      status: result.status,
      reason: result.reason,
      source: result.source,
      confidence: result.confidence,
      checkedAt: result.checkedAt,
    );
  }
}

void main() {
  test('returns unknown when no providers are configured', () async {
    const provider = CompositeUrlReputationProvider(providers: []);

    final result = await provider.checkUrl('https://example.com');

    expect(result.status, UrlReputationStatus.unknown);
    expect(result.reason, contains('No URL reputation providers'));
  });

  test('returns suspicious when any provider reports suspicious', () async {
    const provider = CompositeUrlReputationProvider(
      providers: [
        FixedUrlReputationProvider(
          UrlReputation(url: '', status: UrlReputationStatus.valid),
        ),
        FixedUrlReputationProvider(
          UrlReputation(
            url: '',
            status: UrlReputationStatus.suspicious,
            reason: 'Suspicious URL structure.',
          ),
        ),
      ],
    );

    final result = await provider.checkUrl('https://example.com');

    expect(result.status, UrlReputationStatus.suspicious);
    expect(result.reason, 'Suspicious URL structure.');
  });

  test('malicious result takes priority over suspicious result', () async {
    const provider = CompositeUrlReputationProvider(
      providers: [
        FixedUrlReputationProvider(
          UrlReputation(url: '', status: UrlReputationStatus.suspicious),
        ),
        FixedUrlReputationProvider(
          UrlReputation(
            url: '',
            status: UrlReputationStatus.malicious,
            reason: 'Threat intelligence marked this URL as malicious.',
          ),
        ),
      ],
    );

    final result = await provider.checkUrl('https://example.com');

    expect(result.status, UrlReputationStatus.malicious);
    expect(result.reason, contains('malicious'));
  });

  test('suspicious result takes priority over safe result', () async {
    const provider = CompositeUrlReputationProvider(
      providers: [
        FixedUrlReputationProvider(
          UrlReputation(url: '', status: UrlReputationStatus.safe),
        ),
        FixedUrlReputationProvider(
          UrlReputation(url: '', status: UrlReputationStatus.suspicious),
        ),
      ],
    );

    final result = await provider.checkUrl('https://example.com');

    expect(result.status, UrlReputationStatus.suspicious);
  });

  test(
    'uses valid result when all providers only report valid or unknown',
    () async {
      const provider = CompositeUrlReputationProvider(
        providers: [
          FixedUrlReputationProvider(
            UrlReputation(url: '', status: UrlReputationStatus.unknown),
          ),
          FixedUrlReputationProvider(
            UrlReputation(
              url: '',
              status: UrlReputationStatus.valid,
              reason: 'Structurally valid.',
            ),
          ),
        ],
      );

      final result = await provider.checkUrl('https://example.com');

      expect(result.status, UrlReputationStatus.valid);
      expect(result.reason, 'Structurally valid.');
    },
  );
  test(
    'keeps local suspicious result when online provider is unavailable',
    () async {
      const provider = CompositeUrlReputationProvider(
        providers: [
          FixedUrlReputationProvider(
            UrlReputation(
              url: '',
              status: UrlReputationStatus.suspicious,
              reason: 'Local URL structure is suspicious.',
              source: UrlReputationSource.local,
            ),
          ),
          UnavailableOnlineUrlReputationProvider(),
        ],
      );

      final result = await provider.checkUrl('https://bit.ly/example');

      expect(result.status, UrlReputationStatus.suspicious);
      expect(result.reason, 'Local URL structure is suspicious.');
      expect(result.source, UrlReputationSource.local);
    },
  );
}
