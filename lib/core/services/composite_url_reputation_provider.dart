import '../models/url_reputation.dart';
import 'url_reputation_provider.dart';

class CompositeUrlReputationProvider extends UrlReputationProvider {
  /// Offline providers. Always consulted; they never touch the network.
  final List<UrlReputationProvider> providers;

  /// Providers that leave the device. Only consulted when [onlineEnabled]
  /// returns true at lookup time.
  ///
  /// This is the wiring that makes the "Online link reputation lookup" switch
  /// mean something: before Phase 1 the composite was constructed with the
  /// unavailable-online provider baked in, so opting in changed a label and
  /// nothing else, and opting out could not be checked by any test.
  final List<UrlReputationProvider> onlineProviders;

  /// Read at call time, not construction time, so toggling the setting takes
  /// effect without rebuilding the engine (and its cache).
  final bool Function()? onlineEnabled;

  const CompositeUrlReputationProvider({
    required this.providers,
    this.onlineProviders = const [],
    this.onlineEnabled,
  });

  bool get isOnlineEnabled => onlineEnabled?.call() ?? false;

  @override
  Future<UrlReputation> checkUrl(String url) async {
    if (providers.isEmpty && onlineProviders.isEmpty) {
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

    if (isOnlineEnabled) {
      for (final provider in onlineProviders) {
        results.add(await provider.checkUrl(url));
      }
    }

    if (results.isEmpty) {
      return UrlReputation(
        url: url,
        status: UrlReputationStatus.unknown,
        reason: 'Online lookup is off, so only offline checks were used.',
        source: UrlReputationSource.composite,
      );
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
