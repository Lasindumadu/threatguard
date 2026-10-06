import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/url_reputation.dart';
import 'package:threatguard/core/services/google_web_risk_client.dart';
import 'package:threatguard/core/services/google_web_risk_client_exception.dart';
import 'package:threatguard/core/services/google_web_risk_url_reputation_provider.dart';

class FakeGoogleWebRiskClient extends GoogleWebRiskClient {
  final GoogleWebRiskResponse response;
  final GoogleWebRiskClientException? exception;

  const FakeGoogleWebRiskClient({required this.response, this.exception});

  @override
  Future<GoogleWebRiskResponse> searchUri(String url) async {
    if (exception != null) {
      throw exception!;
    }

    return response;
  }
}

void main() {
  test('marks URL malicious when Web Risk reports a threat', () async {
    const client = FakeGoogleWebRiskClient(
      response: GoogleWebRiskResponse(threatTypes: ['MALWARE']),
    );

    const provider = GoogleWebRiskUrlReputationProvider(client: client);

    final result = await provider.checkUrl('https://malicious.example');

    expect(result.url, 'https://malicious.example');
    expect(result.status, UrlReputationStatus.malicious);
    expect(result.source, UrlReputationSource.online);
    expect(result.reason, contains('MALWARE'));
    expect(result.checkedAt, isNotNull);
  });

  test(
    'marks URL malicious when Web Risk reports social engineering',
    () async {
      const client = FakeGoogleWebRiskClient(
        response: GoogleWebRiskResponse(threatTypes: ['SOCIAL_ENGINEERING']),
      );

      const provider = GoogleWebRiskUrlReputationProvider(client: client);

      final result = await provider.checkUrl('https://phishing.example');

      expect(result.status, UrlReputationStatus.malicious);
      expect(result.source, UrlReputationSource.online);
      expect(result.reason, contains('SOCIAL_ENGINEERING'));
    },
  );

  test('returns unknown when Web Risk reports no matching threat', () async {
    const client = FakeGoogleWebRiskClient(
      response: GoogleWebRiskResponse(threatTypes: []),
    );

    const provider = GoogleWebRiskUrlReputationProvider(client: client);

    final result = await provider.checkUrl('https://example.com');

    expect(result.status, UrlReputationStatus.unknown);
    expect(result.source, UrlReputationSource.online);
    expect(result.reason, contains('did not find'));
    expect(result.checkedAt, isNotNull);
  });

  test('returns unknown for a network error', () async {
    const client = FakeGoogleWebRiskClient(
      response: GoogleWebRiskResponse(threatTypes: []),
      exception: GoogleWebRiskClientException(
        type: GoogleWebRiskClientErrorType.network,
        message: 'Connection failed.',
      ),
    );

    const provider = GoogleWebRiskUrlReputationProvider(client: client);

    final result = await provider.checkUrl('https://example.com');

    expect(result.status, UrlReputationStatus.unknown);
    expect(result.source, UrlReputationSource.online);
    expect(result.reason, 'Google Web Risk could not be reached.');
    expect(result.checkedAt, isNotNull);
  });

  test('returns unknown for a rate limit error', () async {
    const client = FakeGoogleWebRiskClient(
      response: GoogleWebRiskResponse(threatTypes: []),
      exception: GoogleWebRiskClientException(
        type: GoogleWebRiskClientErrorType.rateLimited,
        message: 'Too many requests.',
      ),
    );

    const provider = GoogleWebRiskUrlReputationProvider(client: client);

    final result = await provider.checkUrl('https://example.com');

    expect(result.status, UrlReputationStatus.unknown);
    expect(result.source, UrlReputationSource.online);
    expect(result.reason, 'Google Web Risk rate limit was reached.');
    expect(result.checkedAt, isNotNull);
  });
}
