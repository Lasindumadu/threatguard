import '../models/url_reputation.dart';
import 'url_reputation_provider.dart';

class UnavailableOnlineUrlReputationProvider extends UrlReputationProvider {
  const UnavailableOnlineUrlReputationProvider();

  @override
  Future<UrlReputation> checkUrl(String url) async {
    return UrlReputation(
      url: url,
      status: UrlReputationStatus.unknown,
      reason: 'Online URL reputation service is currently unavailable.',
      source: UrlReputationSource.online,
      checkedAt: DateTime.now(),
    );
  }
}
