import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/message_source.dart';
import 'package:threatguard/core/models/threat_message.dart';
import 'package:threatguard/core/services/template_fingerprint.dart';

void main() {
  group('TemplateFingerprintMatcher', () {
    setUp(TemplateFingerprintMatcher.reset);

    test('matches a campaign variant with a different OTP and URL', () {
      const matcher = TemplateFingerprintMatcher();

      matcher.register(
        'Your parcel is held. Pay the release fee at http://dhl-fee.top now. '
        'Reference 99112233.',
      );

      final match = matcher.match(
        'Your parcel is held. Pay the release fee at http://dhl-fee2.top now. '
        'Reference 44556677.',
      );

      expect(match, isNotNull);
      expect(match!.occurrences, 1);
    });

    test('does not match genuinely different messages', () {
      const matcher = TemplateFingerprintMatcher();

      matcher.register('Your parcel is held, pay the release fee now.');

      final match = matcher.match(
        'Hi, are we still meeting tomorrow at 10 AM about the project?',
      );

      expect(match, isNull);
    });

    test('counts occurrences as a campaign grows', () {
      const matcher = TemplateFingerprintMatcher();

      final body =
          'Congratulations, you have won a cash prize. Claim at http://x.top';

      matcher.register(body);

      // Two more variants of the same campaign.
      matcher.match(
        'Congratulations, you have won a cash prize. Claim at http://y.top',
        register: true,
      );
      matcher.match(
        'Congratulations, you have won a cash prize. Claim at http://z.top',
        register: true,
      );

      final finalMatch = matcher.match(body);

      expect(finalMatch, isNotNull);
      expect(finalMatch!.isCampaign, isTrue);
      expect(finalMatch.occurrences, greaterThanOrEqualTo(3));
    });

    test('reset clears global state between runs', () {
      const matcher = TemplateFingerprintMatcher();
      matcher.register('Your account is suspended, verify now.');

      expect(TemplateFingerprintMatcher.templateCount, 1);

      TemplateFingerprintMatcher.reset();

      expect(TemplateFingerprintMatcher.templateCount, 0);
    });
  });

  group('MessageThreatReport wiring', () {
    test('messages carry a stable id for caching', () {
      const message = ThreatMessage(
        id: 'abc',
        body: 'hello',
        source: MessageSource.sms,
      );

      expect(message.id, 'abc');
    });
  });
}
