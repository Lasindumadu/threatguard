/// Single source of truth for pulling URLs out of a message.
///
/// Before this existed, [ThreatAnalyzer] and [MlFeatureExtractor] each had
/// their own regex. The analyzer found bare domains (`example.com`) while the
/// feature extractor only found scheme-prefixed ones (`https://example.com`),
/// so the rule engine and the ML model literally saw different messages.
class UrlExtractor {
  const UrlExtractor._();

  static final RegExp _pattern = RegExp(
    r'(?:https?://|www\.)[^\s<>"'
    r"'"
    r']+'
    r'|(?<![@\w.-])(?:[\w-]+\.)+[a-z]{2,}(?:/[^\s<>"'
    r"'"
    r']*)?',
    caseSensitive: false,
  );

  /// Returns unique, cleaned URLs in the order they appear.
  static List<String> extract(String text) {
    final seen = <String>{};
    final urls = <String>[];

    for (final match in _pattern.allMatches(text)) {
      final raw = _clean(match.group(0)!);
      if (raw.isEmpty) continue;

      // Reject bracketed IPv6 literals that are not valid IPv6 addresses.
      if (!_isValidBracketedIpv6(raw)) continue;

      // Drop trailing punctuation such as the final "." of a sentence,
      // or closing brackets/parens that are not part of the URL syntax.
      final normalized = _stripTrailingPunctuation(raw);
      if (normalized.isEmpty) continue;

      // A "domain" needs at least one letter after the last dot.
      if (!_looksLikeUrlOrDomain(normalized)) continue;
      if (seen.add(normalized.toLowerCase())) {
        urls.add(normalized);
      }
    }

    return urls;
  }

  static String _stripTrailingPunctuation(String url) {
    // Keep a closing "]" that is part of a valid bracketed IPv6 literal.
    if (url.endsWith(']')) {
      final bracketStart = url.lastIndexOf('[');
      final schemeEnd = url.indexOf('://');
      if (bracketStart != -1 &&
          schemeEnd != -1 &&
          bracketStart > schemeEnd) {
        final addr = url.substring(bracketStart + 1, url.length - 1);
        if (_isValidIpv6Address(addr)) {
          return url;
        }
      }
    }

    return url.replaceAll(RegExp(r'[.,!?;:}\]\)]+$'), '');
  }

  static String _clean(String url) {
    return url.trim();
  }

  static bool _isValidBracketedIpv6(String candidate) {
    final m = RegExp(
      r'^https?://\[([^\]]+)\]',
      caseSensitive: false,
    ).firstMatch(candidate);
    if (m == null) return true;
    return _isValidIpv6Address(m.group(1)!);
  }

  static bool _isValidIpv6Address(String addr) {
    if (!addr.contains(':')) return false;

    final hasCompression = addr.contains('::');

    if (hasCompression) {
      // IPv6 zero-compression (::) may appear only once.
      if (addr.indexOf('::') != addr.lastIndexOf('::')) return false;

      final sides = addr.split('::');

      if (sides.length != 2) return false;

      final left = sides[0].isEmpty ? <String>[] : sides[0].split(':');
      final right = sides[1].isEmpty ? <String>[] : sides[1].split(':');
      final groups = [...left, ...right];

      // Compression must replace at least one 16-bit group.
      if (groups.length >= 8) return false;

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
    final groups = addr.split(':');

    if (groups.length != 8) return false;

    for (final group in groups) {
      if (group.isEmpty ||
          group.length > 4 ||
          !RegExp(r'^[0-9a-fA-F]+$').hasMatch(group)) {
        return false;
      }
    }

    return true;
  }

  static bool _looksLikeUrlOrDomain(String candidate) {
    if (candidate.contains('://')) return true;

    final host = candidate.split('/').first.split('?').first;
    if (!host.contains('.')) return false;

    final tld = host.split('.').last;
    return RegExp(r'^[a-z]{2,}$', caseSensitive: false).hasMatch(tld);
  }
}
