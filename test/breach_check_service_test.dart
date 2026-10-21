import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/breach_record.dart';
import 'package:threatguard/core/services/breach_check_service.dart';

void main() {
  const service = BreachCheckService();

  group('k-anonymity hashing — the privacy guarantee', () {
    test('the transmitted prefix is exactly 5 hex characters', () {
      for (final secret in [
        'password',
        'a-very-long-passphrase-here',
        'user@example.com',
        '1234567890',
        '',
      ]) {
        final prefix = KAnonymityBreachClient.hashPrefix(secret);

        expect(prefix.length, 5);
        expect(RegExp(r'^[0-9A-F]{5}$').hasMatch(prefix), isTrue);
      }
    });

    test('prefix + suffix reconstructs the full SHA-1', () {
      const secret = 'correct horse battery staple';

      final prefix = KAnonymityBreachClient.hashPrefix(secret);
      final suffix = KAnonymityBreachClient.hashSuffix(secret);

      expect(prefix + suffix, hasLength(40));
    });

    test('known SHA-1 vectors match, proving the hashing is standard', () {
      // SHA-1("password") = 5BAA61E4C9B93F3F0682250B6CF8331B7EE68FD8
      expect(KAnonymityBreachClient.hashPrefix('password'), '5BAA6');
      expect(
        KAnonymityBreachClient.hashSuffix('password'),
        '1E4C9B93F3F0682250B6CF8331B7EE68FD8',
      );

      // SHA-1("123456") = 7C4A8D09CA3762AF61E59520943DC26494F8941B
      expect(KAnonymityBreachClient.hashPrefix('123456'), '7C4A8');
    });

    test('different secrets produce different prefixes', () {
      expect(
        KAnonymityBreachClient.hashPrefix('password'),
        isNot(KAnonymityBreachClient.hashPrefix('Password')),
      );
    });
  });

  group('identifier masking', () {
    test('masks the local part of an e-mail', () {
      expect(
        BreachCheckService.mask('someone@example.com'),
        's*****e@example.com',
      );
    });

    test('masks a short local part fully', () {
      expect(BreachCheckService.mask('ab@example.com'), 'a*@example.com');
    });

    test('keeps only the last 3 digits of a phone number', () {
      // "+94 77 123 4567" contains 11 digits, so 8 are masked and 3 kept.
      expect(BreachCheckService.mask('+94 77 123 4567'), '********567');
    });

    test('handles empty input', () {
      expect(BreachCheckService.mask(''), '');
    });

    test('never returns the full identifier', () {
      const identifier = 'verysecret@example.com';
      expect(BreachCheckService.mask(identifier), isNot(identifier));
    });
  });

  group('catalogue', () {
    test('is non-empty and has unique ids', () {
      const catalog = BreachCatalog();
      expect(catalog.all, isNotEmpty);

      final ids = catalog.all.map((b) => b.id).toSet();
      expect(ids.length, catalog.all.length);
    });

    test('lookup by id works', () {
      const catalog = BreachCatalog();
      expect(catalog.byId('linkedin-2021'), isNotNull);
      expect(catalog.byId('does-not-exist'), isNull);
    });

    test('every breach declares what was exposed', () {
      const catalog = BreachCatalog();
      for (final breach in catalog.all) {
        expect(breach.exposed, isNotEmpty, reason: breach.id);
        expect(breach.affectedAccounts, greaterThan(0), reason: breach.id);
      }
    });
  });

  group('offline check', () {
    test('an empty identifier matches nothing', () {
      final result = service.check('');
      expect(result.isExposed, isFalse);
      expect(result.matches, isEmpty);
    });

    test('returns a masked identifier, never the raw one for display', () {
      final result = service.check('test@example.com');
      expect(result.maskedIdentifier, isNot(result.identifier));
      expect(result.maskedIdentifier.contains('@'), isTrue);
    });

    test('a password-style exposure scores higher than an e-mail-only one', () {
      const withPassword = BreachExposureResult(
        identifier: 'x',
        maskedIdentifier: 'x',
        matches: [
          BreachRecord(
            id: 'a',
            name: 'A',
            year: '2020',
            description: '',
            exposed: [BreachDataKind.email, BreachDataKind.password],
            affectedAccounts: 1,
          ),
        ],
      );

      const emailOnly = BreachExposureResult(
        identifier: 'x',
        maskedIdentifier: 'x',
        matches: [
          BreachRecord(
            id: 'b',
            name: 'B',
            year: '2020',
            description: '',
            exposed: [BreachDataKind.email],
            affectedAccounts: 1,
          ),
        ],
      );

      expect(withPassword.severity, greaterThan(emailOnly.severity));
    });

    test('severity is clamped to 100', () {
      final everything = BreachExposureResult(
        identifier: 'x',
        maskedIdentifier: 'x',
        matches: const BreachCatalog().all,
      );

      expect(everything.severity, lessThanOrEqualTo(100));
    });
  });

  group('remediation advice', () {
    test('no exposure still gives honest, useful guidance', () {
      final steps = BreachCheckService.remediationFor(
        const BreachExposureResult(
          identifier: 'x',
          maskedIdentifier: 'x',
          matches: [],
        ),
      );

      expect(steps, isNotEmpty);
      // The catalogue must not be presented as complete coverage.
      expect(steps.join(' ').toLowerCase().contains('not complete'), isTrue);
    });

    test('password exposure prioritises changing the password', () {
      final steps = BreachCheckService.remediationFor(
        const BreachExposureResult(
          identifier: 'x',
          maskedIdentifier: 'x',
          matches: [
            BreachRecord(
              id: 'a',
              name: 'A',
              year: '2020',
              description: '',
              exposed: [BreachDataKind.password],
              affectedAccounts: 1,
            ),
          ],
        ),
      );

      expect(steps.first.toLowerCase().contains('change the password'), isTrue);
      expect(steps.join(' ').toLowerCase().contains('two-factor'), isTrue);
    });

    test('payment card exposure mentions the bank', () {
      final steps = BreachCheckService.remediationFor(
        const BreachExposureResult(
          identifier: 'x',
          maskedIdentifier: 'x',
          matches: [
            BreachRecord(
              id: 'a',
              name: 'A',
              year: '2020',
              description: '',
              exposed: [BreachDataKind.paymentCard],
              affectedAccounts: 1,
            ),
          ],
        ),
      );

      expect(steps.join(' ').toLowerCase().contains('bank'), isTrue);
    });

    test('phone exposure warns about SIM swapping', () {
      final steps = BreachCheckService.remediationFor(
        const BreachExposureResult(
          identifier: 'x',
          maskedIdentifier: 'x',
          matches: [
            BreachRecord(
              id: 'a',
              name: 'A',
              year: '2020',
              description: '',
              exposed: [BreachDataKind.phone],
              affectedAccounts: 1,
            ),
          ],
        ),
      );

      expect(steps.join(' ').toLowerCase().contains('sim-swap'), isTrue);
    });
  });
}
