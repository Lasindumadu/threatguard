import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/message_source.dart';
import 'package:threatguard/core/models/protection_mode.dart';
import 'package:threatguard/core/models/threat_analysis.dart';
import 'package:threatguard/core/models/threat_message.dart';
import 'package:threatguard/core/services/feedback_calibrator.dart';
import 'package:threatguard/core/services/local_store.dart';
import 'package:threatguard/core/services/security_alert_service.dart';
import 'package:threatguard/core/services/threat_engine.dart';

void main() {
  group('FeedbackCalibrator', () {
    const calibrator = FeedbackCalibrator();

    Map<UserFeedback, int> summary({
      int confirmed = 0,
      int falseAlarm = 0,
      int missed = 0,
    }) => {
      UserFeedback.confirmed: confirmed,
      UserFeedback.falseAlarm: falseAlarm,
      UserFeedback.missed: missed,
    };

    test('needs minimum evidence before suggesting', () {
      final advice = calibrator.calibrate(
        summary: summary(confirmed: 2, falseAlarm: 1),
        currentMode: ProtectionMode.strict,
      );
      expect(advice.shouldSuggestChange, isFalse);
      expect(advice.suggestedMode, ProtectionMode.strict);
    });

    test('high false-alarm rate suggests a calmer mode', () {
      final advice = calibrator.calibrate(
        summary: summary(confirmed: 3, falseAlarm: 4),
        currentMode: ProtectionMode.strict,
      );
      expect(advice.shouldSuggestChange, isTrue);
      expect(advice.suggestedMode, ProtectionMode.balanced);
      expect(advice.reason.contains('false alarm'), isTrue);
    });

    test('missed threats never steer towards Relaxed', () {
      final advice = calibrator.calibrate(
        summary: summary(confirmed: 4, falseAlarm: 0, missed: 1),
        currentMode: ProtectionMode.relaxed,
      );
      expect(advice.shouldSuggestChange, isTrue);
      expect(advice.suggestedMode, ProtectionMode.balanced);
    });

    test('repeated misses escalate Balanced to Strict', () {
      final advice = calibrator.calibrate(
        summary: summary(confirmed: 3, missed: 3),
        currentMode: ProtectionMode.balanced,
      );
      expect(advice.shouldSuggestChange, isTrue);
      expect(advice.suggestedMode, ProtectionMode.strict);
    });

    test('healthy history keeps the current mode', () {
      final advice = calibrator.calibrate(
        summary: summary(confirmed: 8, falseAlarm: 1),
        currentMode: ProtectionMode.balanced,
      );
      expect(advice.shouldSuggestChange, isFalse);
    });
  });

  group('SecurityAlertService', () {
    const service = SecurityAlertService();

    MessageThreatReport reportFor(String sender, {DateTime? at}) {
      final engine = ThreatEngine.instance;
      return engine.analyzeMessage(
        ThreatMessage(
          id: 'alert_${sender}_${at?.toIso8601String() ?? 'undated'}',
          body: 'Your account is suspended. Verify your password immediately '
              'at http://evil-$sender.top/login',
          sender: sender,
          source: MessageSource.sms,
          receivedAt: at,
        ),
        mode: ProtectionMode.strict,
      );
    }

    test('raises an alert for repeated high-risk sender', () {
      final now = DateTime.now();
      final reports = [
        reportFor('EVIL', at: now.subtract(const Duration(hours: 1))),
        reportFor('EVIL', at: now.subtract(const Duration(hours: 2))),
        reportFor('EVIL', at: now.subtract(const Duration(hours: 3))),
      ];
      // Ensure they are actually high risk under the test engine.
      expect(
        reports.every(
          (r) => r.analysis.finalLevel == ThreatLevel.highRisk,
        ),
        isTrue,
      );
      final alerts = service.detect(reports, now: now);
      expect(alerts, hasLength(1));
      expect(alerts.first.sender, 'EVIL');
      expect(alerts.first.highRiskCount, 3);
    });

    test('does not alert below the threshold', () {
      final reports = [reportFor('LONELY'), reportFor('LONELY')];
      final alerts = service.detect(reports);
      expect(alerts, isEmpty);
    });

    test('ignores senders outside the window', () {
      final now = DateTime.now();
      final old = now.subtract(const Duration(days: 30));
      final reports = [
        reportFor('OLD', at: old),
        reportFor('OLD', at: old),
        reportFor('OLD', at: old),
      ];
      expect(service.detect(reports, now: now), isEmpty);
    });
  });
}
