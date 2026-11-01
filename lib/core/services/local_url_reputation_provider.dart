import '../models/url_reputation.dart';
import 'url_reputation_provider.dart';

class LocalUrlReputationProvider extends UrlReputationProvider {
  const LocalUrlReputationProvider();

  @override
  Future<UrlReputation> checkUrl(String url) async {
    final checkedAt = DateTime.now();
    final uri = Uri.tryParse(url);

    if (uri == null || uri.host.isEmpty) {
      return UrlReputation(
        url: url,
        status: UrlReputationStatus.invalid,
        reason: 'The URL could not be parsed.',
        source: UrlReputationSource.local,
        checkedAt: checkedAt,
      );
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return UrlReputation(
        url: url,
        status: UrlReputationStatus.invalid,
        reason: 'The URL does not use HTTP or HTTPS.',
        source: UrlReputationSource.local,
        checkedAt: checkedAt,
      );
    }

    final host = uri.host.toLowerCase();

    if (_isIpAddress(host)) {
      return UrlReputation(
        url: url,
        status: UrlReputationStatus.suspicious,
        reason: 'The URL uses an IP address instead of a domain name.',
        source: UrlReputationSource.local,
        checkedAt: checkedAt,
      );
    }

    if (_isShortener(host)) {
      return UrlReputation(
        url: url,
        status: UrlReputationStatus.suspicious,
        reason: 'The URL uses a URL-shortening service, so its final destination is hidden.',
        source: UrlReputationSource.local,
        checkedAt: checkedAt,
      );
    }

    return UrlReputation(
      url: url,
      status: UrlReputationStatus.valid,
      reason: 'The URL is structurally valid, but its safety has not been verified.',
      source: UrlReputationSource.local,
      checkedAt: checkedAt,
    );
  }

  bool _isIpAddress(String host) {
    final parts = host.split('.');

    if (parts.length != 4) {
      return false;
    }

    for (final part in parts) {
      if (part.isEmpty) {
        return false;
      }

      final value = int.tryParse(part);

      if (value == null || value < 0 || value > 255) {
        return false;
      }
    }

    return true;
  }

  bool _isShortener(String host) {
    const shortenerDomains = {
      'bit.ly',
      'tinyurl.com',
      't.co',
      'goo.gl',
      'ow.ly',
      'is.gd',
      'buff.ly',
      'cutt.ly',
      'shorturl.at',
    };

    return shortenerDomains.contains(host);
  }
}
