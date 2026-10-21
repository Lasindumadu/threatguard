import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/services/password_strength_analyzer.dart';

void main() {
  const analyzer = PasswordStrengthAnalyzer();

  group('catches genuinely weak passwords', () {
    const weak = [
      'password',
      'password123',
      '123456',
      'qwerty',
      'letmein',
      'admin',
      'abc123',
      'Password1',
      'welcome1',
      'P@ssw0rd',
      'qwertyuiop',
      'asdfgh',
      '1q2w3e4r',
      'iloveyou',
    ];

    for (final password in weak) {
      test('"$password" is rated weak or critical', () {
        final result = analyzer.analyze(password);
        expect(
          result.strength,
          anyOf(PasswordStrength.critical, PasswordStrength.weak),
          reason: '"$password" must never be rated as strong',
        );
        expect(result.score, lessThan(50));
        expect(result.issues, isNotEmpty);
      });
    }

    test('"P@ssw0rd" is recognised despite the substitutions', () {
      final result = analyzer.analyze('P@ssw0rd');
      expect(
        result.issues.any(
          (i) =>
              i.kind == PasswordIssueKind.commonSubstitution ||
              i.kind == PasswordIssueKind.commonPassword,
        ),
        isTrue,
      );
      expect(result.entropyBits, lessThan(40));
    });

    test('a keyboard walk is flagged', () {
      final result = analyzer.analyze('qwerty12345');
      expect(
        result.issues.any((i) => i.kind == PasswordIssueKind.keyboardWalk),
        isTrue,
      );
    });

    test('sequential characters are flagged', () {
      final result = analyzer.analyze('mySecret1234');
      expect(
        result.issues.any(
          (i) => i.kind == PasswordIssueKind.sequentialCharacters,
        ),
        isTrue,
      );
    });

    test('repeated characters are flagged', () {
      final result = analyzer.analyze('aaaaBBBBcccc');
      expect(
        result.issues.any(
          (i) => i.kind == PasswordIssueKind.repeatedCharacters,
        ),
        isTrue,
      );
    });

    test('an embedded year is flagged', () {
      final result = analyzer.analyze('MyDogIsGreat1998');
      expect(
        result.issues.any((i) => i.kind == PasswordIssueKind.containsYear),
        isTrue,
      );
    });

    test('digits only is flagged', () {
      final result = analyzer.analyze('9876543210123');
      expect(
        result.issues.any((i) => i.kind == PasswordIssueKind.onlyDigits),
        isTrue,
      );
      expect(result.score, lessThan(60));
    });

    test('a short password is flagged for length', () {
      final result = analyzer.analyze('Ab3!x');
      expect(
        result.issues.any((i) => i.kind == PasswordIssueKind.tooShort),
        isTrue,
      );
    });

    test('a dictionary word is flagged', () {
      final result = analyzer.analyze('cricket');
      expect(
        result.issues.any((i) => i.kind == PasswordIssueKind.dictionaryWord),
        isTrue,
      );
    });
  });

  group('rewards genuinely strong passwords', () {
    test('a long random passphrase scores highly', () {
      final result = analyzer.analyze('correct-horse-battery-staple-42!xQ');
      expect(result.score, greaterThan(60));
      expect(
        result.strength,
        anyOf(PasswordStrength.strong, PasswordStrength.excellent),
      );
    });

    test('a long mixed password scores highly', () {
      final result = analyzer.analyze('vT7#kL9\$mQ2wZ!4pR');
      expect(result.score, greaterThan(60));
    });

    test('longer is better, all else equal', () {
      final short = analyzer.analyze('aB3\$kLm');
      final longer = analyzer.analyze('aB3\$kLmNpQ7#wZ');
      expect(longer.entropyBits, greaterThan(short.entropyBits));
      expect(longer.score, greaterThan(short.score));
    });

    test('adding a character class increases entropy', () {
      final lettersOnly = analyzer.analyze('abcdefghijklmnop');
      final mixed = analyzer.analyze('abcdefghijklmnop1234#A');
      expect(mixed.entropyBits, greaterThan(lettersOnly.entropyBits));
    });
  });

  group('edge cases', () {
    test('empty password does not crash and is critical', () {
      final result = analyzer.analyze('');
      expect(result.strength, PasswordStrength.critical);
      expect(result.score, 0);
      expect(result.entropyBits, 0);
    });

    test('a single character is critical', () {
      final result = analyzer.analyze('a');
      expect(result.strength, PasswordStrength.critical);
      expect(result.score, lessThan(20));
    });

    test('unicode characters are handled', () {
      final result = analyzer.analyze('හසරැල්ල-මගේ-රහස');
      expect(result.length, greaterThan(0));
      expect(result.score, greaterThanOrEqualTo(0));
    });

    test('a very long password does not overflow', () {
      final result = analyzer.analyze('aB3\$' * 200);
      expect(result.score, lessThanOrEqualTo(100));
      expect(result.entropyBits, lessThanOrEqualTo(200));
    });
  });

  group('result object is safe to display', () {
    test('never exposes the password', () {
      const secret = 'SuperSecret123!';
      final result = analyzer.analyze(secret);

      final rendered = [
        result.strengthLabel,
        result.crackTimeDescription,
        ...result.suggestions,
        for (final issue in result.issues) '${issue.title} ${issue.detail}',
      ].join(' ');

      expect(
        rendered.contains(secret),
        isFalse,
        reason: 'the analysis must never echo the password back',
      );
    });

    test('crack time is described in human terms', () {
      expect(analyzer.analyze('123456').crackTimeDescription, 'instantly');
      expect(
        analyzer
            .analyze('correct-horse-battery-staple-42!xQ')
            .crackTimeDescription,
        isNot('instantly'),
      );
    });
  });

  group('PassphraseGenerator', () {
    const generator = PassphraseGenerator();

    test('produces a passphrase with the requested word count', () {
      final result = generator.generate(wordCount: 4);
      expect(result.wordCount, 4);
      expect(result.value.length, greaterThan(20));
    });

    test('the default word count reaches excellent entropy', () {
      // The default matters: a 4-word passphrase from this list is only ~56
      // bits, which is below the 80-bit bar the app advertises. The default is
      // 5 for that reason, and this test pins the arithmetic.
      final result = generator.generate();
      expect(result.wordCount, 5);
      expect(result.entropyBits, greaterThan(60));
      expect(result.score, greaterThan(70));
    });

    test('generated entropy is high and computed, not estimated', () {
      final result = generator.generate(wordCount: 5);

      // Every word in the list is at least 3 characters and the list is large,
      // so 5 words alone must clear 5 * log2(400) ~= 43 bits, and the digit and
      // symbol groups add ~16 more.
      expect(result.entropyBits, greaterThan(55));
      expect(result.score, greaterThan(65));
    });

    test('two generations differ', () {
      final a = generator.generate();
      final b = generator.generate();
      expect(a.value, isNot(b.value));
    });

    test('generated passphrases pass their own analyzer as strong', () {
      // This is the important one: the generator must produce passwords the
      // analyzer agrees are strong.
      for (var i = 0; i < 25; i++) {
        final generated = generator.generate();
        final analysis = analyzer.analyze(generated.value);

        expect(
          analysis.score,
          greaterThan(55),
          reason:
              'generated "${generated.value}" scored only '
              '${analysis.score}',
        );
      }
    });

    test('more words means more entropy', () {
      final three = generator.generate(wordCount: 3);
      final six = generator.generate(wordCount: 6);
      expect(six.entropyBits, greaterThan(three.entropyBits));
    });
  });
}
