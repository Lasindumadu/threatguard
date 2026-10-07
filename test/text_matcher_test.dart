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
}
