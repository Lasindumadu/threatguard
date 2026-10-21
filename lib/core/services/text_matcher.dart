import 'text_preprocessor.dart';

/// Whole-word phrase matching with light de-obfuscation.
///
/// - Phrases must match on word boundaries ("pin" no longer matches "shopping").
/// - Simple plurals match ("prize" matches "prizes").
/// - Text is also checked in a de-obfuscated form ("v3rify" -> "verify"),
///   while the original form is kept so things like "24 hours" still match.
///
/// The de-obfuscation itself lives in [TextPreprocessor], which is the single
/// normalization every engine uses. This class only owns phrase compilation and
/// the one-entry memo the analyzer relies on (~200 calls per message).
class TextMatcher {
  const TextMatcher._();

  static final Map<String, RegExp> _cache = {};

  static bool contains(String text, String phrase) {
    final regex = _cache.putIfAbsent(phrase, () => _compile(phrase));
    for (final variant in TextPreprocessor.variantsOf(text)) {
      if (regex.hasMatch(variant)) return true;
    }
    return false;
  }

  static bool containsAny(String text, Iterable<String> phrases) {
    return phrases.any((p) => contains(text, p));
  }

  /// The literal text that matched [phrase], or null.
  ///
  /// Used for evidence capture: the UI shows what was actually in the
  /// message (including plurals and de-obfuscated spellings), not the
  /// canonical pattern spelling.
  static String? firstMatch(String text, String phrase) {
    final regex = _cache.putIfAbsent(phrase, () => _compile(phrase));
    for (final variant in TextPreprocessor.variantsOf(text)) {
      final match = regex.firstMatch(variant);
      if (match != null) return match.group(0);
    }
    return null;
  }

  /// The normalized, case-folded text the matchers actually search.
  ///
  /// Exposed so callers that run many independent scans (the feature
  /// extractor, the analyzer) can normalize once instead of relying on the
  /// single-entry memo. Delegates to [TextPreprocessor] — there is one
  /// definition of normalization in the app.
  static String normalize(String text) => TextPreprocessor.normalize(text);

  static RegExp _compile(String phrase) {
    final p = phrase.trim().toLowerCase();
    final body = p.split(RegExp(r'\s+')).map(RegExp.escape).join(r'\s+');
    final endsWithLetter = RegExp(r'\p{L}$', unicode: true).hasMatch(p);
    final plural = endsWithLetter ? '(?:e?s)?' : '';
    return RegExp(
      '(?<![\\p{L}\\p{N}\\p{M}])$body$plural(?![\\p{L}\\p{N}\\p{M}])',
      unicode: true,
    );
  }
}
