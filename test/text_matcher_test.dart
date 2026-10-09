import 'package:flutter_test/flutter_test.dart';
import 'package:threatguard/core/services/text_matcher.dart';

void main() {
  test('does not match inside longer words', () {
    expect(TextMatcher.contains('i love shopping', 'pin'), isFalse);
    expect(TextMatcher.contains('enter your pin now', 'pin'), isTrue);
  });

  test('matches simple plurals', () {
    expect(TextMatcher.contains('you won two prizes', 'prize'), isTrue);
  });

  test('catches leetspeak obfuscation', () {
    expect(
      TextMatcher.contains('v3rify your acc0unt', 'verify your account'),
      isTrue,
    );
  });

  test('keeps numbers intact', () {
    expect(
      TextMatcher.contains('reply within 24 hours', 'within 24 hours'),
      isTrue,
    );
  });

  test('ignores zero-width characters and extra spaces', () {
    expect(
      TextMatcher.contains(
        'ver\u200Bify   your account',
        'verify your account',
      ),
      isTrue,
    );
  });

  test('does not match when a combining mark continues a word', () {
    expect(TextMatcher.contains('p\u0301in', 'pin'), isFalse);
  });

  test('matches a normal word next to combining-mark text correctly', () {
    expect(TextMatcher.contains('enter your pin\u0301 now', 'pin'), isFalse);
    expect(TextMatcher.contains('enter your pin now', 'pin'), isTrue);
  });

  test('does not match a Sinhala phrase inside a longer word', () {
    expect(TextMatcher.contains('ඔබගේගිණුම', 'ගිණුම'), isFalse);
    expect(TextMatcher.contains('ඔබගේ ගිණුම', 'ගිණුම'), isTrue);
  });

  test('does not match a Tamil phrase inside a longer word', () {
    expect(TextMatcher.contains('உங்கள்கணக்கு', 'கணக்கு'), isFalse);
    expect(TextMatcher.contains('உங்கள் கணக்கு', 'கணக்கு'), isTrue);
  });

  test('does not join English words across a ZWJ', () {
    expect(
      TextMatcher.contains('verify\u200Daccount', 'verify account'),
      isFalse,
    );
  });

  test('does not join English words across a ZWNJ', () {
    expect(
      TextMatcher.contains('verify\u200Caccount', 'verify account'),
      isFalse,
    );
  });

  test('matches precomposed Unicode text', () {
    expect(TextMatcher.contains('Café payment', 'café'), isTrue);
  });

  test('does not collapse intentionally spaced letters into a keyword', () {
    expect(
      TextMatcher.contains('v e r i f y your account', 'verify your account'),
      isFalse,
    );
  });
}
