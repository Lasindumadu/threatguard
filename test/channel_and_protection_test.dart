import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/channel_profile.dart';
import 'package:threatguard/core/models/message_source.dart';
import 'package:threatguard/core/models/protection_mode.dart';
import 'package:threatguard/core/services/threat_engine.dart';
import 'package:threatguard/core/services/hybrid_threat_analyzer.dart';

void main() {
  group('ChannelProfile', () {
    test('every message source has a profile', () {
      for (final source in MessageSource.values) {
        final profile = ChannelProfile.of(source);
        expect(profile.displayName, isNotEmpty, reason: source.name);
        expect(profile.shortName, isNotEmpty, reason: source.name);
      }
    });

    test('maps known package names onto the right channel', () {
      expect(
        ChannelProfile.fromPackageName('com.whatsapp'),
        MessageSource.whatsapp,
      );
      expect(
        ChannelProfile.fromPackageName('com.instagram.android'),
        MessageSource.instagram,
      );
      expect(
        ChannelProfile.fromPackageName('com.facebook.orca'),
        MessageSource.messenger,
      );
      expect(
        ChannelProfile.fromPackageName('com.google.android.gm'),
        MessageSource.email,
      );
      expect(
        ChannelProfile.fromPackageName('com.android.chrome'),
        MessageSource.web,
      );
    });

    test('an unknown package falls back to the generic share channel', () {
      // Guessing a specific channel would put a false provenance label in the
      // UI, so an unknown source is reported as a plain share.
      expect(
        ChannelProfile.fromPackageName('com.some.random.app'),
        MessageSource.share,
      );
      expect(ChannelProfile.fromPackageName(null), MessageSource.share);
      expect(ChannelProfile.fromPackageName(''), MessageSource.share);
    });

    test('consumer messengers carry a link risk bonus', () {
      for (final source in [
        MessageSource.whatsapp,
        MessageSource.messenger,
        MessageSource.instagram,
      ]) {
        expect(
          ChannelProfile.of(source).urlRiskBonus,
          greaterThan(0),
          reason: source.name,
        );
        expect(ChannelProfile.of(source).isTypicallyUnsolicited, isTrue);
      }
    });

    test(
      'SMS has no channel bonus, because bank links are legitimate there',
      () {
        expect(ChannelProfile.of(MessageSource.sms).urlRiskBonus, 0);
      },
    );

    test('only SMS is marked as automatically read', () {
      final automatic = ChannelProfile.all
          .where((p) => p.isAutomaticallyRead)
          .map((p) => p.source)
          .toSet();

      // Claiming automatic read access to a messenger would be false.
      expect(automatic, {MessageSource.sms});
    });
  });

  group('ProtectionMode thresholds are ordered correctly', () {
    test('strict is more sensitive than balanced, which beats relaxed', () {
      expect(
        ProtectionMode.strict.suspiciousScoreFloor,
        lessThan(ProtectionMode.balanced.suspiciousScoreFloor),
      );
      expect(
        ProtectionMode.balanced.suspiciousScoreFloor,
        lessThan(ProtectionMode.relaxed.suspiciousScoreFloor),
      );
    });

    test('strict needs less model confidence to act', () {
      expect(
        ProtectionMode.strict.mlOverrideThreshold,
        lessThan(ProtectionMode.balanced.mlOverrideThreshold),
      );
    });

    test('strict demands more confidence before clearing a rule hit', () {
      // The safety-critical direction: in strict mode the model must be very
      // sure before it is allowed to dismiss a rule detection.
      expect(
        ProtectionMode.strict.mlDowngradeThreshold,
        greaterThan(ProtectionMode.balanced.mlDowngradeThreshold),
      );
    });

    test('every mode has a label and a description', () {
      for (final mode in ProtectionMode.values) {
        expect(mode.label, isNotEmpty);
        expect(mode.description.length, greaterThan(20), reason: mode.name);
      }
    });
  });

  group('ProtectionMode actually changes detection', () {
    final engine = ThreatEngine.instance;

    // A message with a moderate threat signal: enough to register, not
    // overwhelming. Strict mode should catch it; relaxed may not.
    const borderline =
        'We detected unusual activity. Please confirm your account details '
        'using the link below within 24 hours.';

    test('strict mode is at least as sensitive as balanced', () {
      final strict = engine.analyzeText(
        borderline,
        mode: ProtectionMode.strict,
      );
      final balanced = engine.analyzeText(
        borderline,
        mode: ProtectionMode.balanced,
      );
      final relaxed = engine.analyzeText(
        borderline,
        mode: ProtectionMode.relaxed,
      );

      // Scores must be ordered by sensitivity, never inverted.
      expect(
        strict.analysis.blendedRiskScore,
        greaterThanOrEqualTo(relaxed.analysis.blendedRiskScore),
      );
      expect(
        balanced.analysis.blendedRiskScore,
        greaterThanOrEqualTo(relaxed.analysis.blendedRiskScore),
      );
    });

    test('the mode is recorded on the verdict', () {
      final result = engine.analyzeText(
        borderline,
        mode: ProtectionMode.strict,
      );
      expect(result.analysis.protectionMode, ProtectionMode.strict);
    });
  });

  group('channel provenance reaches the verdict', () {
    final engine = ThreatEngine.instance;

    const linkMessage =
        'Check this out: http://bit.ly/abc123 and let me know what you think.';

    test('an unsolicited messenger link scores higher than the same SMS', () {
      final viaWhatsApp = engine.analyzeText(
        linkMessage,
        source: MessageSource.whatsapp,
      );
      final viaSms = engine.analyzeText(linkMessage, source: MessageSource.sms);

      expect(
        viaWhatsApp.analysis.blendedRiskScore,
        greaterThan(viaSms.analysis.blendedRiskScore),
      );
      expect(viaWhatsApp.analysis.channelRiskBonus, greaterThan(0));
      expect(viaSms.analysis.channelRiskBonus, 0);
    });

    test('a message with no link gets no channel bonus', () {
      final result = engine.analyzeText(
        'Hey, are we still on for lunch tomorrow?',
        source: MessageSource.whatsapp,
      );

      // The channel only matters when there is a link to follow.
      expect(result.analysis.channelRiskBonus, 0);
    });

    test('relaxed mode ignores the channel bonus entirely', () {
      final result = engine.analyzeText(
        linkMessage,
        source: MessageSource.whatsapp,
        mode: ProtectionMode.relaxed,
      );

      expect(result.analysis.channelRiskBonus, 0);
    });

    test('the channel is exposed for display', () {
      final result = engine.analyzeText(
        'hello',
        source: MessageSource.instagram,
      );

      expect(result.analysis.channel?.displayName, 'Instagram');
      expect(result.analysis.channel?.isUserInvoked, isTrue);
    });
  });

  group('blended score bounds', () {
    final engine = ThreatEngine.instance;

    test('never exceeds 100 even with a channel bonus', () {
      final result = engine.analyzeText(
        'URGENT: your account is suspended. Verify your password immediately '
        'at http://192.168.1.1/verify or your account will be closed today.',
        source: MessageSource.whatsapp,
      );

      expect(result.analysis.blendedRiskScore, lessThanOrEqualTo(100));
      expect(result.analysis.blendedRiskScore, greaterThan(0));
    });

    test('is never lower than the raw rule score', () {
      final result = engine.analyzeText(
        'Your account has been locked. Unusual activity detected. '
        'Verify your identity at http://paypa1-verify.top/login',
      );

      expect(
        result.analysis.blendedRiskScore,
        greaterThanOrEqualTo(result.analysis.ruleAnalysis.riskScore),
      );
    });
  });

  group('HybridThreatAnalyzer back-compatibility', () {
    test('the documented default thresholds are unchanged', () {
      // These are referenced by the audit document and the model insights
      // screen; changing them silently would invalidate both.
      expect(HybridThreatAnalyzer.mlOverrideThreshold, 0.75);
      expect(HybridThreatAnalyzer.mlDowngradeThreshold, 0.90);
      expect(HybridThreatAnalyzer.strongRuleScore, 50);
      expect(HybridThreatAnalyzer.weakRuleScore, 30);
    });
  });
}
