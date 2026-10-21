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

      // Drop trailing punctuation such as the final "." of a sentence.
      final normalized = raw.replaceAll(RegExp(r'[.,!?;:]+$'), '');
      if (normalized.isEmpty) continue;

      // A "domain" needs at least one letter after the last dot.
      if (!_looksLikeUrlOrDomain(normalized)) continue;
      if (seen.add(normalized.toLowerCase())) {
        urls.add(normalized);
      }
    }

    return urls;
  }

  static String _clean(String url) {
    return url.trim();
  }

  static bool _looksLikeUrlOrDomain(String candidate) {
    if (candidate.contains('://')) return true;

    final host = candidate.split('/').first.split('?').first;
    if (!host.contains('.')) return false;

    final tld = host.split('.').last;
    return RegExp(r'^[a-z]{2,}$', caseSensitive: false).hasMatch(tld);
  }
}
