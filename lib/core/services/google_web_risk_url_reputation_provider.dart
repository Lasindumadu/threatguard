import '../models/url_reputation.dart';
import 'google_web_risk_client.dart';
import 'google_web_risk_client_exception.dart';
import 'url_reputation_provider.dart';

class GoogleWebRiskUrlReputationProvider extends UrlReputationProvider {
  final GoogleWebRiskClient client;

  const GoogleWebRiskUrlReputationProvider({required this.client});

  @override
  Future<UrlReputation> checkUrl(String url) async {
    final checkedAt = DateTime.now();

    try {
      final response = await client.searchUri(url);

      if (response.threatTypes.isNotEmpty) {
        return UrlReputation(
          url: url,
          status: UrlReputationStatus.malicious,
          reason: _buildThreatReason(response.threatTypes),
          source: UrlReputationSource.online,
          checkedAt: checkedAt,
        );
      }

      return UrlReputation(
        url: url,
        status: UrlReputationStatus.unknown,
        reason: 'Google Web Risk did not find the URL on the requested threat lists.',
        source: UrlReputationSource.online,
        checkedAt: checkedAt,
      );
    } on GoogleWebRiskClientException catch (error) {
      return UrlReputation(
        url: url,
        status: UrlReputationStatus.unknown,
        reason: _buildErrorReason(error),
        source: UrlReputationSource.online,
        checkedAt: checkedAt,
      );
    } catch (_) {
      return UrlReputation(
        url: url,
        status: UrlReputationStatus.unknown,
        reason: 'Google Web Risk encountered an unexpected error.',
        source: UrlReputationSource.online,
        checkedAt: checkedAt,
      );
    }
  }

  String _buildThreatReason(List<String> threatTypes) {
    return 'Google Web Risk identified the URL as '
        '${threatTypes.join(', ')}.';
  }

  String _buildErrorReason(GoogleWebRiskClientException error) {
    switch (error.type) {
      case GoogleWebRiskClientErrorType.unauthorized:
        return 'Google Web Risk authentication failed.';

      case GoogleWebRiskClientErrorType.forbidden:
        return 'Google Web Risk access was denied.';

      case GoogleWebRiskClientErrorType.rateLimited:
        return 'Google Web Risk rate limit was reached.';

      case GoogleWebRiskClientErrorType.serverError:
        return 'Google Web Risk service is temporarily unavailable.';

      case GoogleWebRiskClientErrorType.network:
        return 'Google Web Risk could not be reached.';

      case GoogleWebRiskClientErrorType.invalidResponse:
        return 'Google Web Risk returned an invalid response.';

      case GoogleWebRiskClientErrorType.unknown:
        return 'Google Web Risk returned an unexpected error.';
    }
  }
}
