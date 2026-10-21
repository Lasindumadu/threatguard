import 'dart:convert';

import 'threat_engine.dart';

/// Evidence that a message is a near-duplicate of others already scanned.
///
/// Campaign detection is one of the strongest real-world signals: a lone
/// lottery SMS is weak evidence, but the 47th identical-with-tweaks copy is a
/// mass campaign almost by definition.
class TemplateMatch {
  /// Stable identifier of the normalised template.
  final String fingerprint;

  /// How many previously-seen messages share this template (excluding the
  /// current one).
  final int occurrences;

  /// A representative message body from the campaign, for display.
  final String? sample;

  const TemplateMatch({
    required this.fingerprint,
    required this.occurrences,
    this.sample,
  });

  bool get isCampaign => occurrences >= 2;
}

/// Shingle-hash based near-duplicate detector.
///
/// Messages are normalised (lower-cased, digits and URLs replaced with
/// placeholders, punctuation stripped), split into word 3-grams, hashed, and
/// compared by Jaccard similarity. Two variants of the same scam template
/// ("your OTP 4821" vs "your OTP 9137") therefore collapse to one fingerprint.
class TemplateFingerprintMatcher {
  const TemplateFingerprintMatcher({
    this.shingleSize = 3,
    this.similarityThreshold = 0.72,
  });

  final int shingleSize;
  final double similarityThreshold;

  static final Map<String, _RegisteredTemplate> _global = {};

  /// Registers every report's fingerprint so later messages can match them.
  void registerAll(List<MessageThreatReport> reports) {
    for (final report in reports) {
      register(report.message.body);
    }
  }

  void register(String body) {
    final shingles = _shingles(_normalize(body));
    if (shingles.isEmpty) return;

    for (final entry in _global.entries) {
      if (_jaccard(shingles, entry.value.shingles) >= similarityThreshold) {
        _global[entry.key] = entry.value.bump(body);
        return;
      }
    }

    final fingerprint = _hash(shingles.join('|'));
    _global[fingerprint] = _RegisteredTemplate(
      fingerprint: fingerprint,
      shingles: shingles,
      count: 1,
      sample: body,
    );
  }

  /// Only reports a match for templates already registered at least once.
  TemplateMatch? match(String body, {bool register = false}) {
    final shingles = _shingles(_normalize(body));
    if (shingles.isEmpty) return null;

    for (final entry in _global.entries) {
      final similarity = _jaccard(shingles, entry.value.shingles);
      if (similarity >= similarityThreshold) {
        if (register) {
          _global[entry.key] = entry.value.bump(body);
        }
        return TemplateMatch(
          fingerprint: entry.key,
          occurrences: entry.value.count,
          sample: entry.value.sample,
        );
      }
    }

    if (register) {
      this.register(body);
    }

    return null;
  }

  static void reset() => _global.clear();

  static int get templateCount => _global.length;

  // ---------------------------------------------------------------- internals

  static String _normalize(String body) {
    var text = body.toLowerCase();

    // Collapse URLs, e-mails, long digit runs (OTPs, account numbers,
    // reference ids, dates) and money amounts so template variants align.
    text = text.replaceAll(
      RegExp(r'https?://\S+|www\.\S+|\S+@\S+\.\S+'),
      ' <url> ',
    );
    text = text.replaceAll(RegExp(r'\b\d[\d\s\-/]{2,}\b'), ' <num> ');
    text = text.replaceAll(RegExp(r'[^\p{L}<>\s]', unicode: true), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }

  List<String> _shingles(String normalizedText) {
    final words = normalizedText.split(' ').where((w) => w.isNotEmpty).toList();

    if (words.isEmpty) return const [];

    if (words.length < shingleSize) {
      return [_hash(words.join('-'))];
    }

    final result = <String>[];
    for (var i = 0; i + shingleSize <= words.length; i++) {
      result.add(_hash(words.sublist(i, i + shingleSize).join('-')));
    }
    return result;
  }

  static String _hash(String input) {
    // FNV-1a — small, fast, dependency-free, good enough for shingles.
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(input)) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  static double _jaccard(List<String> a, List<String> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;

    final setA = a.toSet();
    final setB = b.toSet();

    var intersection = 0;
    for (final value in setA) {
      if (setB.contains(value)) intersection++;
    }

    final union = setA.length + setB.length - intersection;
    return union == 0 ? 0.0 : intersection / union;
  }
}

class _RegisteredTemplate {
  final String fingerprint;
  final List<String> shingles;
  final int count;
  final String sample;

  const _RegisteredTemplate({
    required this.fingerprint,
    required this.shingles,
    required this.count,
    required this.sample,
  });

  _RegisteredTemplate bump(String newSample) {
    return _RegisteredTemplate(
      fingerprint: fingerprint,
      shingles: shingles,
      count: count + 1,
      // Keep the shortest sample as the "canonical" campaign text.
      sample: newSample.length < sample.length ? newSample : sample,
    );
  }
}
