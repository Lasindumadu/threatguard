import '../models/url_reputation.dart';

abstract class UrlReputationProvider {
  const UrlReputationProvider();

  Future<UrlReputation> checkUrl(String url);
}
