import '../models/url_reputation.dart';
import 'url_reputation_provider.dart';

class CompositeUrlReputationProvider extends UrlReputationProvider {
  final List<UrlReputationProvider> providers;

  const CompositeUrlReputationProvider({required this.providers});

  @override
  Future<UrlReputation> checkUrl(String url) async {
    if (providers.isEmpty) {
      return UrlReputation(
        url: url,
        status: UrlReputationStatus.unknown,
        reason: 'No URL reputation providers are configured.',
        source: UrlReputationSource.composite,
      );
    }

    final results = <UrlReputation>[];

    for (final provider in providers) {
      results.add(await provider.checkUrl(url));
    }

    return _combineResults(url, results);
  }

  UrlReputation _combineResults(String url, List<UrlReputation> results) {
    for (final status in [
      UrlReputationStatus.malicious,
      UrlReputationStatus.suspicious,
      UrlReputationStatus.invalid,
      UrlReputationStatus.safe,
      UrlReputationStatus.valid,
      UrlReputationStatus.unknown,
    ]) {
      for (final result in results) {
        if (result.status == status) {
          return result;
        }
      }
    }

    return UrlReputation(
      url: url,
      status: UrlReputationStatus.unknown,
      reason: 'No reputation result was available.',
      source: UrlReputationSource.composite,
    );
  }
}
