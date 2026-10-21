/// The single text-normalization step every engine runs on its input.
///
/// Phase 1 finding: normalization was implemented **twice** — `TextMatcher`
/// cleaned text for phrase matching and the rule engine trimmed it on its own,
/// while the model, the URL analyzer and the verdict policy each had their own
/// notion of "the message". That is how two engines end up judging slightly
/// different messages.
///
/// This class owns:
///
///  * bounding (a pasted 200 KB forward must not make regex scanning
///    quadratic),
///  * whitespace collapsing (so sentence splitting and phrase matching agree),
///  * a normalization for *matching* (case-folded, invisible characters
///    removed, fullwidth/homoglyph folds applied),
///  * a small Unicode-safety guard for lone surrogates, which `substring` can
///    otherwise split in half.
///
/// It deliberately does **not** lower-case the display text: the UI must show
/// what the user actually received.
class TextPreprocessor {
  const TextPreprocessor._();

  /// Upper bound on the characters any detector sees.
  ///
  /// MMS, e-mail forwards and pasted transcripts can be tens of kilobytes;
  /// every rule is a regex over the text, so an unbounded input makes detection
  /// latency proportional to message size. Truncation is always *reported* by
  /// the rule engine (`ThreatAnalysis.wasTruncated`).
  static const int maxLength = 8000;

  /// Bound [text] to [maxLength] characters without splitting a surrogate
  /// pair, and without cutting the string in the middle of a grapheme cluster
  /// (a combining mark is dropped with its base character).
  static BoundedText bound(String? text, {int maxLength = maxLength}) {
    final trimmed = (text ?? '').trim();
    if (trimmed.length <= maxLength) {
      return BoundedText(text: trimmed, wasTruncated: false);
    }

    var end = maxLength;

    // Never split a surrogate pair.
    final unit = trimmed.codeUnitAt(end - 1);
    if (unit >= 0xD800 && unit <= 0xDBFF) end -= 1;

    // Drop leading combining marks that lost their base character.
    while (end > 0 && _isCombiningMark(trimmed.codeUnitAt(end))) {
      end -= 1;
    }

    return BoundedText(
      text: trimmed.substring(0, end).trimRight(),
      wasTruncated: true,
    );
  }

  /// Whitespace-collapsed, trimmed text with no normalization applied.
  ///
  /// Used for display and for URL extraction (lower-casing a URL would change
  /// it, and collapsing whitespace inside one is harmless because URLs cannot
  /// contain spaces).
  static String tidy(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// The text the matchers search: case-folded, with obfuscation removed.
  ///
  /// Every rule, phrase list and feature derives from this one function, so
  /// `v3rify y0ur p4ssword`, `ＶＥＲＩＦＹ` (fullwidth) and a Cyrillic-`о`
  /// lookalike are all the same string to every engine.
  static String normalize(String text) => TextNormalization.of(text).clean;

  /// Every matching form of [text]. Usually one; two when leetspeak folding
  /// changed something, so "24" in the original is still searched as "24".
  static List<String> variantsOf(String text) =>
      TextNormalization.of(text).variants;

  /// The text to run *matching* over once.
  ///
  /// Callers that scan rather than quote evidence (the rule engine, the
  /// feature extractor, the verdict policy) use this, so obfuscated and
  /// fullwidth spellings reach them at all. `TextMatcher` still scans both
  /// forms, because evidence must quote the user's original characters.
  ///
  /// This is the case-folded, homoglyph- and invisible-character-folded form;
  /// leetspeak folding is applied per phrase by [TextMatcher], because doing it
  /// globally would rewrite numbers ("24 hours", "$500") that rules match
  /// literally.
  static String matchingForm(String text) => TextNormalization.of(text).clean;

  /// Longest word a pattern is allowed to start inside.
  ///
  /// Detectors run word-boundary look-behinds at *every* character. On a token
  /// of 200 000 characters (one pasted line, base64 blob, or a forward with no
  /// line breaks) the look-behind has to inspect the whole prefix at each
  /// position, which is quadratic: measured on this machine, one 200 KB paste
  /// took ~25 s to become a verdict — enough to freeze the UI thread. Capping
  /// the token length makes that linear again.
  static const int maxTokenLength = 256;

  /// Inserts a space inside any token longer than [maxTokenLength].
  ///
  /// Applied before every detector runs. `wasTruncated` stays false: the
  /// characters are all still analysed, they are just no longer one unbroken
  /// word, and no real word is 256 characters long.
  static String capTokenLength(
    String text, {
    int maxTokenLength = maxTokenLength,
  }) {
    // Fast path: a pattern needs a token this long to be able to start inside
    // the look-behind, and `contains` on a short needle is linear.
    if (!text.contains(_tokenFill)) return text;

    final run = RegExp('[^\\s]{${maxTokenLength + 1},}');
    return text.replaceAllMapped(run, (match) {
      final token = match[0]!;
      final buffer = StringBuffer();
      for (var i = 0; i < token.length; i += maxTokenLength) {
        if (i > 0) buffer.write(' ');
        final end = i + maxTokenLength > token.length
            ? token.length
            : i + maxTokenLength;
        buffer.write(token.substring(i, end));
      }
      return buffer.toString();
    });
  }

  /// Used only for the fast-path `contains` check: a token of this many
  /// characters can only exist if the text itself contains this substring.
  static final String _tokenFill = 'a' * (maxTokenLength + 1);

  static bool _isCombiningMark(int codeUnit) {
    return (codeUnit >= 0x0300 && codeUnit <= 0x036F) ||
        (codeUnit >= 0x1AB0 && codeUnit <= 0x1AFF) ||
        (codeUnit >= 0x1DC0 && codeUnit <= 0x1DFF) ||
        (codeUnit >= 0x20D0 && codeUnit <= 0x20FF) ||
        (codeUnit >= 0xFE20 && codeUnit <= 0xFE2F);
  }
}

/// A bounded input plus whether anything was dropped.
class BoundedText {
  final String text;
  final bool wasTruncated;

  const BoundedText({required this.text, required this.wasTruncated});
}

/// The cached normalization of one string.
///
/// `TextMatcher` called this for every phrase it searched (~200 times per
/// message); computing the variants once per message, and caching the last
/// one, keeps the cost at a single pass. The cache is keyed by identity *and*
/// equality so a re-entrant call with a different string cannot observe a
/// half-updated entry.
class TextNormalization {
  final String raw;
  final String clean;
  final List<String> variants;

  const TextNormalization._(this.raw, this.clean, this.variants);

  static String? _lastRaw;
  static TextNormalization? _last;

  static TextNormalization of(String text) {
    final cached = _last;
    if (cached != null && identical(text, _lastRaw) && cached.raw == text) {
      return cached;
    }
    if (cached != null && cached.raw == text) return cached;

    final clean = _clean(text);
    final deleet = _deleet(clean);
    final value = TextNormalization._(
      text,
      clean,
      deleet == clean ? [clean] : [clean, deleet],
    );

    // Assign the key last, so a throw above can never leave a stale entry.
    _last = value;
    _lastRaw = text;
    return value;
  }

  /// Clears the one-entry memo. Only needed by tests.
  static void resetCache() {
    _last = null;
    _lastRaw = null;
  }

  static String _clean(String input) {
    // Remove invisible characters used to break up keywords.
    // NOTE: U+200D (ZWJ) and U+200C (ZWNJ) are deliberately kept because
    // Sinhala conjunct letters depend on them.
    final t = input.replaceAll(_invisible, '').toLowerCase();

    // Every replacement below is 1:1, so the whole string can be rewritten in
    // one pass. The previous rune-by-rune `StringBuffer.write(fromCharCode)`
    // version behaved like an O(n²) string append: 8 000 characters took
    // ~650 ms, on every sentence of every analysis.
    final folded = t.replaceAllMapped(_foldable, (match) {
      final char = match[0]!;
      final rune = char.runes.single;

      if (rune >= 0xFF01 && rune <= 0xFF5E) {
        // Fullwidth ASCII -> normal ASCII
        return String.fromCharCode(rune - 0xFEE0);
      }

      return _lookalikes[rune] ?? char;
    });

    return folded.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Invisible characters used to split keywords. Removed *before* case
  /// folding, because some platforms fold U+00AD (soft hyphen) into a space.
  static final RegExp _invisible = RegExp('[\u200B\u2060\uFEFF\u00AD]');

  /// Characters that a 1-character replacement exists for.
  static final RegExp _foldable = RegExp(
    r'[\uFF01-\uFF5E\u0430\u0435\u043E\u0440\u0441\u0445\u0443\u0456\u03BF]',
    unicode: true,
  );

  static final RegExp _hasLetter = RegExp(r'\p{L}', unicode: true);

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
