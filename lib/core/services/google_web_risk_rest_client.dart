import 'dart:convert';

import 'google_web_risk_client.dart';
import 'google_web_risk_client_exception.dart';

class GoogleWebRiskRestClient extends GoogleWebRiskClient {
  final GoogleWebRiskHttpClient httpClient;
  final String apiKey;

  const GoogleWebRiskRestClient({
    required this.httpClient,
    required this.apiKey,
  });

  @override
  Future<GoogleWebRiskResponse> searchUri(String url) async {
    final query = [
      'key=${Uri.encodeQueryComponent(apiKey)}',
      'uri=${Uri.encodeQueryComponent(url)}',
      'threatTypes=${Uri.encodeQueryComponent('MALWARE')}',
      'threatTypes=${Uri.encodeQueryComponent('SOCIAL_ENGINEERING')}',
    ].join('&');

    final uri = Uri.parse(
      'https://webrisk.googleapis.com/v1/uris:search?$query',
    );

    final response = await httpClient.get(uri: uri);

    if (response.statusCode == 401) {
      throw const GoogleWebRiskClientException(
        type: GoogleWebRiskClientErrorType.unauthorized,
        message: 'Google Web Risk authentication failed.',
      );
    }

    if (response.statusCode == 403) {
      throw const GoogleWebRiskClientException(
        type: GoogleWebRiskClientErrorType.forbidden,
        message: 'Google Web Risk access was denied.',
      );
    }

    if (response.statusCode == 429) {
      throw const GoogleWebRiskClientException(
        type: GoogleWebRiskClientErrorType.rateLimited,
        message: 'Google Web Risk rate limit was reached.',
      );
    }

    if (response.statusCode >= 500) {
      throw const GoogleWebRiskClientException(
        type: GoogleWebRiskClientErrorType.serverError,
        message: 'Google Web Risk service returned a server error.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const GoogleWebRiskClientException(
        type: GoogleWebRiskClientErrorType.unknown,
        message: 'Google Web Risk returned an unexpected HTTP status.',
      );
    }

    return _parseResponse(response.body);
  }

  GoogleWebRiskResponse _parseResponse(String body) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Response is not a JSON object.');
      }

      final threat = decoded['threat'];

      if (threat == null) {
        return const GoogleWebRiskResponse(threatTypes: []);
      }

      if (threat is! Map<String, dynamic>) {
        throw const FormatException('Threat field is not an object.');
      }

      final rawThreatTypes = threat['threatTypes'];

      if (rawThreatTypes is! List) {
        throw const FormatException('Threat types field is not a list.');
      }

      final threatTypes = rawThreatTypes.whereType<String>().toList(
        growable: false,
      );

      DateTime? expireTime;

      final rawExpireTime = threat['expireTime'];

      if (rawExpireTime is String) {
        expireTime = DateTime.tryParse(rawExpireTime);
      }

      return GoogleWebRiskResponse(
        threatTypes: threatTypes,
        expireTime: expireTime,
      );
    } catch (_) {
      throw const GoogleWebRiskClientException(
        type: GoogleWebRiskClientErrorType.invalidResponse,
        message: 'Google Web Risk returned an invalid response.',
      );
    }
  }
}
