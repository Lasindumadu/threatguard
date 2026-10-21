import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/campaign_advisory.dart';
import 'package:threatguard/core/models/message_source.dart';
import 'package:threatguard/core/models/security_posture.dart';
import 'package:threatguard/core/models/threat_message.dart';
import 'package:threatguard/core/services/security_tips_engine.dart';
import 'package:threatguard/core/services/threat_engine.dart';

void main() {
  group('SecurityPosture scoring', () {
    const assessor = SecurityPostureAssessor();

    SecurityPosture build({
      bool? screenLock = true,
      bool? sms = true,
      bool onlineLookup = false,
      bool strict = true,
      int muted = 1,
      int feedback = 1,
      int scanned = 5,
      int highRisk = 0,
    }) {
      return assessor.assess(
        screenLockEnabled: screenLock,
        smsPermissionGranted: sms,
        onlineLookupEnabled: onlineLookup,
        strictModeEnabled: strict,
        mutedSenderCount: muted,
        feedbackGiven: feedback,
        scannedMessages: scanned,
        highRiskMessages: highRisk,
      );
    }

    test('a well-configured device scores strongly', () {
      final posture = build();
      expect(posture.score, greaterThanOrEqualTo(85));
      expect(posture.grade, PostureGrade.strong);
    });

    test('no screen lock is a significant failure', () {
      final locked = build();
      final unlocked = build(screenLock: false);
      expect(unlocked.score, lessThan(locked.score));
      expect(unlocked.failures.any((c) => c.id == 'screen_lock'), isTrue);
    });

    test(
      'unknown checks are excluded from the score, not counted as passes',
      () {
        final withLock = build(screenLock: true);
        final unknownLock = build(screenLock: null);

        // An unobservable check must not raise the score.
        expect(unknownLock.score, lessThanOrEqualTo(withLock.score));
        expect(
          unknownLock.checks.firstWhere((c) => c.id == 'screen_lock').status,
          PostureStatus.unknown,
        );
      },
    );

    test('the two genuinely unobservable checks are always unknown', () {
      final posture = build();
      for (final id in ['os_patch', 'unknown_sources']) {
        final check = posture.checks.firstWhere((c) => c.id == id);
        expect(check.status, PostureStatus.unknown, reason: id);
      }
      expect(posture.unknownCount, greaterThanOrEqualTo(2));
    });

    test('score never exceeds 100', () {
      expect(build().score, lessThanOrEqualTo(100));
    });

    test('a hostile configuration scores poorly', () {
      final posture = build(
        screenLock: false,
        sms: false,
        strict: false,
        onlineLookup: true,
        muted: 0,
        feedback: 0,
        scanned: 0,
        highRisk: 10,
      );
      expect(posture.score, lessThan(50));
      expect(posture.grade, anyOf(PostureGrade.poor, PostureGrade.weak));
      expect(posture.failures, isNotEmpty);
    });
  });

  group('ThreatFeedCatalog', () {
    const catalog = ThreatFeedCatalog();

    test('every advisory is complete', () {
      for (final campaign in catalog.all) {
        expect(campaign.title, isNotEmpty, reason: campaign.id);
        expect(campaign.summary.length, greaterThan(60), reason: campaign.id);
        expect(campaign.typicalWording, isNotEmpty, reason: campaign.id);
        expect(campaign.objective, isNotEmpty, reason: campaign.id);
        expect(campaign.defence, isNotEmpty, reason: campaign.id);
        expect(campaign.relatedTool, isNotEmpty, reason: campaign.id);
      }
    });

    test('ids are unique', () {
      final ids = catalog.all.map((c) => c.id).toSet();
      expect(ids.length, catalog.all.length);
    });

    test('categories can be filtered', () {
      expect(catalog.categories, isNotEmpty);
      for (final category in catalog.categories) {
        expect(catalog.byCategory(category), isNotEmpty);
      }
    });

    test('there are enough campaigns to be a useful reference', () {
      expect(catalog.all.length, greaterThanOrEqualTo(6));
    });
  });

  group('SecurityTipsEngine', () {
    const engine = SecurityTipsEngine();
    final threatEngine = ThreatEngine.instance;

    List<MessageThreatReport> reportsFor(List<String> bodies) {
      return [
        for (var i = 0; i < bodies.length; i++)
          threatEngine.analyzeMessage(
            ThreatMessage(
              id: 'tip_$i',
              body: bodies[i],
              source: MessageSource.sms,
            ),
          ),
      ];
    }

    test('an empty inbox advises enabling scanning', () {
      final tips = engine.generate(
        reports: const [],
        feedbackCount: 0,
        mutedSenderCount: 0,
        hasSmsPermission: false,
      );

      expect(tips, isNotEmpty);
      expect(tips.first.id, 'start_scan');
    });

    test(
      'a delivery-scam cluster produces a targeted tip citing the count',
      () {
        final reports = reportsFor(const [
          'Your parcel is held at customs, pay the release fee now.',
          'Your package could not be delivered. Pay the redelivery fee.',
          'A shipment is waiting for you, a small fee is required.',
        ]);

        final tips = engine.generate(
          reports: reports,
          feedbackCount: 1,
          mutedSenderCount: 1,
          hasSmsPermission: true,
        );

        final tip = tips.firstWhere(
          (t) => t.id == 'delivery_cluster',
          orElse: () => throw StateError('expected a delivery-cluster tip'),
        );

        // The tip must cite the user's own data, not give generic advice.
        expect(tip.observation.contains('3'), isTrue);
      },
    );

    test('tips are ordered by priority, highest first', () {
      final reports = reportsFor(const [
        'Your account is suspended. Verify your password immediately.',
        'Verify your identity at http://evil.top to restore access.',
      ]);

      final tips = engine.generate(
        reports: reports,
        feedbackCount: 0,
        mutedSenderCount: 0,
        hasSmsPermission: false,
      );

      for (var i = 1; i < tips.length; i++) {
        expect(tips[i - 1].priority, greaterThanOrEqualTo(tips[i].priority));
      }
    });

    test('fundamental advice is always present even with no threats', () {
      final tips = engine.generate(
        reports: reportsFor(const ['Hi, see you at 10am tomorrow.']),
        feedbackCount: 1,
        mutedSenderCount: 1,
        hasSmsPermission: true,
      );

      final ids = tips.map((t) => t.id).toSet();
      expect(ids.contains('reuse_fundamental'), isTrue);
      expect(ids.contains('screen_lock_fundamental'), isTrue);
    });

    test('every tip has both an observation and an action', () {
      final reports = reportsFor(const [
        'Your parcel is held, pay the fee now.',
        'You have won a cash prize, claim now.',
        'Verify your password immediately.',
      ]);

      final tips = engine.generate(
        reports: reports,
        feedbackCount: 0,
        mutedSenderCount: 0,
        hasSmsPermission: false,
      );

      for (final tip in tips) {
        expect(tip.observation, isNotEmpty, reason: tip.id);
        expect(tip.action, isNotEmpty, reason: tip.id);
        expect(tip.priority, inInclusiveRange(0, 100));
      }
    });

    test('no feedback yet produces a nudge', () {
      final tips = engine.generate(
        reports: reportsFor(const ['Hello there.']),
        feedbackCount: 0,
        mutedSenderCount: 1,
        hasSmsPermission: true,
      );

      expect(tips.any((t) => t.id == 'no_feedback'), isTrue);
    });
  });
}
