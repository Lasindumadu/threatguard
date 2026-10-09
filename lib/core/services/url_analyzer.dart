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

    final uriInput = normalizedUrl.contains('://')
        ? normalizedUrl
        : 'https://$normalizedUrl';

    final uri = Uri.tryParse(uriInput);

    if (uri == null || uri.host.isEmpty) {
      return UrlAnalysis(
        url: normalizedUrl,
        host: '',
        domain: null,
        signals: const [],
      );
    }

    final host = uri.host.toLowerCase();
    final rawHost = _extractRawHost(uriInput);

    final signals = <UrlSignal>[
      ..._detectIpAddressHost(host),
      ..._detectPunycodeHost(host),
      ..._detectMixedScriptHost(rawHost),
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
    if (_isValidIpv4(host) || _isValidIpv6(host)) {
      return const [
        UrlSignal(
          type: UrlSignalType.ipAddressHost,
          title: 'IP address used as hostname',
          description: 'The URL uses an IP address instead of a conventional domain name.',
        ),
      ];
    }

    return const [];
  }

  bool _isValidIpv4(String host) {
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

  bool _isValidIpv6(String host) {
    if (!host.contains(':')) {
      return false;
    }

    final hasCompression = host.contains('::');

    if (hasCompression) {
      // IPv6 zero-compression (::) may appear only once.
      if (host.indexOf('::') != host.lastIndexOf('::')) {
        return false;
      }

      final sides = host.split('::');

      if (sides.length != 2) {
        return false;
      }

      final left = sides[0].isEmpty ? <String>[] : sides[0].split(':');
      final right = sides[1].isEmpty ? <String>[] : sides[1].split(':');

      final groups = [...left, ...right];

      // Compression must replace at least one 16-bit group.
      if (groups.length >= 8) {
        return false;
      }

      for (final group in groups) {
        if (group.isEmpty ||
            group.length > 4 ||
            !RegExp(r'^[0-9a-fA-F]+$').hasMatch(group)) {
          return false;
        }
      }

      return true;
    }

    // Without ::, IPv6 must contain exactly eight 16-bit groups.
    final groups = host.split(':');

    if (groups.length != 8) {
      return false;
    }

    for (final group in groups) {
      if (group.isEmpty ||
          group.length > 4 ||
          !RegExp(r'^[0-9a-fA-F]+$').hasMatch(group)) {
        return false;
      }
    }

    return true;
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

  String _extractRawHost(String url) {
    final withoutScheme = url.replaceFirst(
      RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false),
      '',
    );

    final authorityEnd = RegExp(r'[/?#]').firstMatch(withoutScheme)?.start;
    final authority = authorityEnd == null
        ? withoutScheme
        : withoutScheme.substring(0, authorityEnd);

    final withoutCredentials = authority.contains('@')
        ? authority.substring(authority.lastIndexOf('@') + 1)
        : authority;

    // IPv6 literals are enclosed in brackets.
    if (withoutCredentials.startsWith('[')) {
      final closingBracket = withoutCredentials.indexOf(']');

      if (closingBracket != -1) {
        return withoutCredentials.substring(1, closingBracket).toLowerCase();
      }
    }

    // Remove an optional port from ordinary hostnames.
    final colonIndex = withoutCredentials.lastIndexOf(':');

    if (colonIndex != -1 &&
        withoutCredentials
            .substring(colonIndex + 1)
            .contains(RegExp(r'^\d+$'))) {
      return withoutCredentials.substring(0, colonIndex).toLowerCase();
    }

    return withoutCredentials.toLowerCase();
  }

  List<UrlSignal> _detectMixedScriptHost(String host) {
    var hasLatin = false;
    var hasCyrillic = false;
    var hasGreek = false;

    for (final rune in host.runes) {
      if (_isLatinRune(rune)) {
        hasLatin = true;
      } else if (_isCyrillicRune(rune)) {
        hasCyrillic = true;
      } else if (_isGreekRune(rune)) {
        hasGreek = true;
      }
    }

    final hasMultipleScripts =
        (hasLatin && hasCyrillic) ||
        (hasLatin && hasGreek) ||
        (hasCyrillic && hasGreek);

    if (!hasMultipleScripts) {
      return const [];
    }

    return const [
      UrlSignal(
        type: UrlSignalType.mixedScriptHost,
        title: 'Mixed-script hostname',
        description: 'The hostname contains characters from multiple writing systems and may use visually deceptive characters.',
      ),
    ];
  }

  bool _isLatinRune(int rune) {
    return (rune >= 0x0041 && rune <= 0x005A) ||
        (rune >= 0x0061 && rune <= 0x007A) ||
        (rune >= 0x00C0 && rune <= 0x024F);
  }

  bool _isCyrillicRune(int rune) {
    return rune >= 0x0400 && rune <= 0x04FF;
  }

  bool _isGreekRune(int rune) {
    return rune >= 0x0370 && rune <= 0x03FF;
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

    const multiLabelPublicSuffixes = {
      'co.uk',
      'org.uk',
      'ac.uk',
      'gov.uk',
      'co.lk',
      'com.lk',
      'org.lk',
      'net.lk',
      'gov.lk',
      'ac.lk',
    };

    if (parts.length >= 3) {
      final suffix = '${parts[parts.length - 2]}.${parts[parts.length - 1]}';

      if (multiLabelPublicSuffixes.contains(suffix)) {
        return '${parts[parts.length - 3]}.$suffix';
      }
    }

    return '${parts[parts.length - 2]}.${parts[parts.length - 1]}';
  }
}
