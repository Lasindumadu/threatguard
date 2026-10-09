/// Whole-word phrase matching with light de-obfuscation.
///
/// - Phrases must match on word boundaries ("pin" no longer matches "shopping").
/// - Simple plurals match ("prize" matches "prizes").
/// - Text is also checked in a de-obfuscated form ("v3rify" -> "verify"),
///   while the original form is kept so things like "24 hours" still match.
class TextMatcher {
  const TextMatcher._();

  static final Map<String, RegExp> _cache = {};
  static final RegExp _hasLetter = RegExp(r'\p{L}', unicode: true);

  // One-entry memo: the analyzer calls contains() ~200 times on the same text.
  static String? _lastRaw;
  static List<String> _lastVariants = const [];

  static bool contains(String text, String phrase) {
    final regex = _cache.putIfAbsent(phrase, () => _compile(phrase));
    for (final variant in _variantsFor(text)) {
      if (regex.hasMatch(variant)) return true;
    }
    return false;
  }

  static bool containsAny(String text, Iterable<String> phrases) {
    return phrases.any((p) => contains(text, p));
  }

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

  static List<String> _variantsFor(String raw) {
    if (raw != _lastRaw) {
      final clean = _clean(raw);
      final deleet = _deleet(clean);
      _lastVariants = deleet == clean ? [clean] : [clean, deleet];
      _lastRaw = raw;
    }
    return _lastVariants;
  }

  static String _clean(String input) {
    // Remove invisible characters used to break up keywords.
    // NOTE: U+200D (ZWJ) and U+200C (ZWNJ) are deliberately kept because
    // Sinhala conjunct letters depend on them.
    var t = input.toLowerCase().replaceAll(
      RegExp('[\u200B\u2060\uFEFF\u00AD]'),
      '',
    );

    final buf = StringBuffer();
    for (final r in t.runes) {
      if (r >= 0xFF01 && r <= 0xFF5E) {
        // Fullwidth ASCII -> normal ASCII
        buf.writeCharCode(r - 0xFEE0);
      } else {
        buf.write(_lookalikes[r] ?? String.fromCharCode(r));
      }
    }
    t = buf.toString();
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Replaces leetspeak characters, only inside tokens that contain a letter
  /// and are not URLs, so "$500" and "24" are left alone.
  static String _deleet(String s) {
    return s.replaceAllMapped(RegExp(r'\S+'), (m) {
      final tok = m[0]!;
      if (tok.contains('://') || tok.startsWith('www.')) return tok;
      if (!_hasLetter.hasMatch(tok)) return tok;
      return tok.split('').map((c) => _leet[c] ?? c).join();
    });
  }

  static const Map<String, String> _leet = {
    '0': 'o',
    '1': 'i',
    '3': 'e',
    '4': 'a',
    '5': 's',
    '7': 't',
    '@': 'a',
    '\$': 's',
  };

  // Cyrillic / Greek letters that look like Latin ones.
  static const Map<int, String> _lookalikes = {
    0x0430: 'a',
    0x0435: 'e',
    0x043E: 'o',
    0x0440: 'p',
    0x0441: 'c',
    0x0445: 'x',
    0x0443: 'y',
    0x0456: 'i',
    0x03BF: 'o',
  };
}
