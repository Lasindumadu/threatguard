import 'url_extractor.dart';

/// One URL as it appeared in a message, plus where it came from.
///
/// The distinction matters. A URL *found inside* a message is prose that
/// happens to contain a link. A URL the user *pasted as the whole check* is not
/// a message at all: before this existed, pasting
/// `https://accounts.example.com/reset?t=abc` made the message analyzer treat
/// the path segment `accounts.example.com` as a second, embedded domain and
/// charged it the "external URL" rule. The URL a user asked about should be
/// inspected by the URL engines, not re-parsed as text.
class ExtractedUrl {
  /// The cleaned URL exactly as it appeared.
  final String url;

  /// True when the whole input was a single URL, rather than text containing
  /// one.
  final bool isPrimary;

  const ExtractedUrl({required this.url, this.isPrimary = false});

  @override
  String toString() => 'ExtractedUrl($url${isPrimary ? ', primary' : ''})';
}

/// Shared URL extraction for every analysis entry point.
///
/// Thin wrappers keep the provenance decision in one place so the rule engine,
/// the feature extractor and the URL reputation path can never disagree about
/// whether a message "has a link".
class UrlAnalysisInput {
  const UrlAnalysisInput._();

  /// Extracts URLs from message prose.
  static List<ExtractedUrl> fromMessage(String? text) {
    if (text == null || text.trim().isEmpty) return const [];

    return [
      for (final url in UrlExtractor.extract(text)) ExtractedUrl(url: url),
    ];
  }

  /// Extracts the URL from a value the user supplied *as* a URL.
  ///
  /// Returns an empty list when the input is not a single URL (no scheme, no
  /// host, or additional prose), so the caller can fall back honestly instead
  /// of inventing a destination.
  static List<ExtractedUrl> fromPastedValue(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return const [];

    final candidates = UrlExtractor.extract(trimmed);

    // A pasted link is one URL that either carries a scheme or starts the text.
    if (candidates.isEmpty) return const [];

    final first = candidates.first;
    final hasScheme = RegExp(
      r'^[a-z][a-z0-9+.-]*://',
      caseSensitive: false,
    ).hasMatch(trimmed.toLowerCase());

    final startsAtZero = trimmed.toLowerCase().startsWith(first.toLowerCase());

    if (!hasScheme && !startsAtZero) return const [];

    return [ExtractedUrl(url: first, isPrimary: true)];
  }
}
