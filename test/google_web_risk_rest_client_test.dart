import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/services/google_web_risk_client.dart';
import 'package:threatguard/core/services/google_web_risk_client_exception.dart';
import 'package:threatguard/core/services/google_web_risk_rest_client.dart';

class FakeGoogleWebRiskHttpClient extends GoogleWebRiskHttpClient {
  final GoogleWebRiskHttpResponse response;
  Uri? requestedUri;

  FakeGoogleWebRiskHttpClient({required this.response});

  @override
  Future<GoogleWebRiskHttpResponse> get({required Uri uri}) async {
    requestedUri = uri;
    return response;
  }
}

void main() {
  test('parses a malicious Web Risk response', () async {
    final httpClient = FakeGoogleWebRiskHttpClient(
      response: const GoogleWebRiskHttpResponse(
        statusCode: 200,
        body: '''
{
  "threat": {
    "threatTypes": ["MALWARE"],
    "expireTime": "2030-01-01T00:00:00Z"
  }
}
''',
      ),
    );

    final client = GoogleWebRiskRestClient(
      httpClient: httpClient,
      apiKey: 'test-api-key',
    );

    final result = await client.searchUri('https://example.com/malware');

    expect(result.threatTypes, ['MALWARE']);
    expect(result.expireTime, isNotNull);
    expect(result.expireTime, DateTime.parse('2030-01-01T00:00:00Z'));

    expect(httpClient.requestedUri, isNotNull);
    expect(
      httpClient.requestedUri!.queryParameters['uri'],
      'https://example.com/malware',
    );
    expect(httpClient.requestedUri!.queryParameters['key'], 'test-api-key');
    expect(httpClient.requestedUri!.queryParametersAll['threatTypes'], [
      'MALWARE',
      'SOCIAL_ENGINEERING',
    ]);
  });

  test('parses multiple Web Risk threat types', () async {
    final httpClient = FakeGoogleWebRiskHttpClient(
      response: const GoogleWebRiskHttpResponse(
        statusCode: 200,
        body: '''
{
  "threat": {
    "threatTypes": [
      "MALWARE",
      "SOCIAL_ENGINEERING"
    ],
    "expireTime": "2030-01-01T00:00:00Z"
  }
}
''',
      ),
    );

    final client = GoogleWebRiskRestClient(
      httpClient: httpClient,
      apiKey: 'test-api-key',
    );

    final result = await client.searchUri('https://example.com/threat');

    expect(result.threatTypes, ['MALWARE', 'SOCIAL_ENGINEERING']);

    expect(result.expireTime, DateTime.parse('2030-01-01T00:00:00Z'));
  });

  test('parses an empty Web Risk response as no threats', () async {
    final httpClient = FakeGoogleWebRiskHttpClient(
      response: const GoogleWebRiskHttpResponse(statusCode: 200, body: '{}'),
    );

    final client = GoogleWebRiskRestClient(
      httpClient: httpClient,
      apiKey: 'test-api-key',
    );

    final result = await client.searchUri('https://example.com');

    expect(result.threatTypes, isEmpty);
    expect(result.expireTime, isNull);
  });

  test('throws unauthorized error for HTTP 401', () async {
    final httpClient = FakeGoogleWebRiskHttpClient(
      response: const GoogleWebRiskHttpResponse(statusCode: 401, body: '{}'),
    );

    final client = GoogleWebRiskRestClient(
      httpClient: httpClient,
      apiKey: 'test-api-key',
    );

    expect(
      () => client.searchUri('https://example.com'),
      throwsA(
        isA<GoogleWebRiskClientException>().having(
          (error) => error.type,
          'type',
          GoogleWebRiskClientErrorType.unauthorized,
        ),
      ),
    );
  });

  test('throws rate limit error for HTTP 429', () async {
    final httpClient = FakeGoogleWebRiskHttpClient(
      response: const GoogleWebRiskHttpResponse(statusCode: 429, body: '{}'),
    );

    final client = GoogleWebRiskRestClient(
      httpClient: httpClient,
      apiKey: 'test-api-key',
    );

    expect(
      () => client.searchUri('https://example.com'),
      throwsA(
        isA<GoogleWebRiskClientException>().having(
          (error) => error.type,
          'type',
          GoogleWebRiskClientErrorType.rateLimited,
        ),
      ),
    );
  });

  test('throws invalid response error for malformed JSON', () async {
    final httpClient = FakeGoogleWebRiskHttpClient(
      response: const GoogleWebRiskHttpResponse(
        statusCode: 200,
        body: 'not-json',
      ),
    );

    final client = GoogleWebRiskRestClient(
      httpClient: httpClient,
      apiKey: 'test-api-key',
    );

    expect(
      () => client.searchUri('https://example.com'),
      throwsA(
        isA<GoogleWebRiskClientException>().having(
          (error) => error.type,
          'type',
          GoogleWebRiskClientErrorType.invalidResponse,
        ),
      ),
    );
  });
}
