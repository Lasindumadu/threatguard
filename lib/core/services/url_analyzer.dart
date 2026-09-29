import '../models/url_analysis.dart';

class UrlAnalyzer {
  const UrlAnalyzer();

  static const _urlShorteners = {
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

  List<UrlAnalysis> analyzeAll(List<String> urls) {
    return urls.map(analyze).toList(growable: false);
  }

  UrlAnalysis analyze(String url) {
    final normalizedUrl = url.trim();

    final uri = Uri.tryParse(
      normalizedUrl.contains('://') ? normalizedUrl : 'https://$normalizedUrl',
    );

    if (uri == null || uri.host.isEmpty) {
      return UrlAnalysis(
        url: normalizedUrl,
        host: '',
        domain: null,
        signals: const [],
      );
    }

    final host = uri.host.toLowerCase();

    final signals = <UrlSignal>[
      ..._detectIpAddressHost(host),
      ..._detectPunycodeHost(host),
      ..._detectEmbeddedCredentials(uri),
      ..._detectNonStandardPort(uri),
      ..._detectExcessiveSubdomains(host),
      ..._detectUrlShortener(host),
    ];

    return UrlAnalysis(
      url: normalizedUrl,
      host: host,
      domain: _extractDomain(host),
      signals: List.unmodifiable(signals),
    );
  }

  List<UrlSignal> _detectIpAddressHost(String host) {
    final ipv4Pattern = RegExp(r'^(?:\d{1,3}\.){3}\d{1,3}$');

    if (!ipv4Pattern.hasMatch(host)) {
      return const [];
    }

    return const [
      UrlSignal(
        type: UrlSignalType.ipAddressHost,
        title: 'IP address used as hostname',
        description:
            'The URL uses an IP address instead of a conventional domain name.',
      ),
    ];
  }

  List<UrlSignal> _detectPunycodeHost(String host) {
    final labels = host.split('.');

    if (!labels.any((label) => label.startsWith('xn--'))) {
      return const [];
    }

    return const [
      UrlSignal(
        type: UrlSignalType.punycodeHost,
        title: 'Punycode hostname',
        description: 'The hostname contains an internationalized domain label represented using Punycode.',
      ),
    ];
  }

  List<UrlSignal> _detectEmbeddedCredentials(Uri uri) {
    if (uri.userInfo.isEmpty) {
      return const [];
    }

    return const [
      UrlSignal(
        type: UrlSignalType.embeddedCredentials,
        title: 'Embedded user information',
        description: 'The URL contains user information before the hostname, which can be used in deceptive URL structures.',
      ),
    ];
  }

  List<UrlSignal> _detectNonStandardPort(Uri uri) {
    if (uri.port == 0) {
      return const [];
    }

    final isStandardHttpPort = uri.scheme == 'http' && uri.port == 80;

    final isStandardHttpsPort = uri.scheme == 'https' && uri.port == 443;

    if (isStandardHttpPort || isStandardHttpsPort) {
      return const [];
    }

    return [
      const UrlSignal(
        type: UrlSignalType.nonStandardPort,
        title: 'Non-standard port',
        description: 'The URL uses a port other than the standard port normally associated with its scheme.',
      ),
    ];
  }

  List<UrlSignal> _detectExcessiveSubdomains(String host) {
    final labels = host.split('.');

    /*
     * A conventional hostname such as:
     *
     * example.com
     *
     * has two labels.
     *
     * login.example.com
     *
     * has three.
     *
     * We flag five or more labels as a structural signal.
     * This is not proof of maliciousness.
     */

    if (labels.length < 5) {
      return const [];
    }

    return const [
      UrlSignal(
        type: UrlSignalType.excessiveSubdomains,
        title: 'Deep subdomain structure',
        description: 'The hostname contains several nested subdomains and may require additional inspection.',
      ),
    ];
  }

  List<UrlSignal> _detectUrlShortener(String host) {
    if (!_urlShorteners.contains(host)) {
      return const [];
    }

    return const [
      UrlSignal(
        type: UrlSignalType.urlShortener,
        title: 'URL shortener detected',
        description: 'The URL uses a known URL-shortening service, which hides the final destination.',
      ),
    ];
  }

  String? _extractDomain(String host) {
    if (host.isEmpty) {
      return null;
    }

    final parts = host.split('.');

    if (parts.length < 2) {
      return null;
    }

    /*
     * Conservative first version:
     *
     * example.com
     *     -> example.com
     *
     * login.example.com
     *     -> example.com
     *
     * Public-suffix handling such as example.co.uk will be
     * addressed separately when required.
     */

    return '${parts[parts.length - 2]}.${parts[parts.length - 1]}';
  }
}
