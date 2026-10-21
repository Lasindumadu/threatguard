import '../models/protection_mode.dart';
import 'local_store.dart';

/// How the app should adapt to this user's feedback history.
///
/// The feedback loop from 2.0 collected verdicts but never *used* them.
/// This closes that loop: repeated false alarms suggest the current mode is
/// too aggressive for this user's traffic, while missed threats suggest it is
/// too lax. The result is advisory — the mode never changes silently.
class CalibrationAdvice {
  final ProtectionMode currentMode;
  final ProtectionMode suggestedMode;

  /// Human-readable reason citing the user's own numbers.
  final String reason;

  /// True when there is enough signal to suggest a change.
  final bool shouldSuggestChange;

  const CalibrationAdvice({
    required this.currentMode,
    required this.suggestedMode,
    required this.reason,
    required this.shouldSuggestChange,
  });
}

/// Derives per-user threshold advice from confirmed/false-alarm history.
///
/// Safety floors (non-negotiable):
/// * A user with any missed threat is never steered towards Relaxed.
/// * A suggestion requires a minimum evidence count so one stray tap cannot
///   retrain the app.
/// * The advice never auto-applies — the user stays in control.
class FeedbackCalibrator {
  const FeedbackCalibrator();

  /// Minimum feedback events before any suggestion is made.
  static const int minEvidence = 5;

  /// False-alarm rate above which the mode is likely too aggressive.
  static const double falseAlarmRateThreshold = 0.30;

  /// Miss count that forces at least Balanced, regardless of false alarms.
  static const int missedThreatFloor = 1;

  CalibrationAdvice calibrate({
    required Map<UserFeedback, int> summary,
    required ProtectionMode currentMode,
  }) {
    final confirmed = summary[UserFeedback.confirmed] ?? 0;
    final falseAlarms = summary[UserFeedback.falseAlarm] ?? 0;
    final missed = summary[UserFeedback.missed] ?? 0;
    final total = confirmed + falseAlarms + missed;

    if (total < minEvidence) {
      return CalibrationAdvice(
        currentMode: currentMode,
        suggestedMode: currentMode,
        reason:
            'Rate $total more verdicts to personalise sensitivity '
            '($minEvidence needed).',
        shouldSuggestChange: false,
      );
    }

    // Safety floor first: a missed threat means Relaxed is off the table.
    if (missed >= missedThreatFloor) {
      if (currentMode == ProtectionMode.relaxed) {
        return CalibrationAdvice(
          currentMode: currentMode,
          suggestedMode: ProtectionMode.balanced,
          reason:
              'You reported $missed missed ${missed == 1 ? 'threat' : 'threats'} — '
              'Relaxed mode may be letting attacks through. Balanced is safer.',
          shouldSuggestChange: true,
        );
      }
      if (currentMode == ProtectionMode.balanced && missed >= 3) {
        return CalibrationAdvice(
          currentMode: currentMode,
          suggestedMode: ProtectionMode.strict,
          reason:
              'You reported $missed missed threats. Strict mode catches '
              'borderline cases at the cost of more false alarms.',
          shouldSuggestChange: true,
        );
      }
      return CalibrationAdvice(
        currentMode: currentMode,
        suggestedMode: currentMode,
        reason: 'Sensitivity looks right for your traffic.',
        shouldSuggestChange: false,
      );
    }

    final falseAlarmRate = falseAlarms / total;
    if (falseAlarmRate >= falseAlarmRateThreshold &&
        currentMode != ProtectionMode.relaxed) {
      final suggested = currentMode == ProtectionMode.strict
          ? ProtectionMode.balanced
          : ProtectionMode.relaxed;
      return CalibrationAdvice(
        currentMode: currentMode,
        suggestedMode: suggested,
        reason:
            '${(falseAlarmRate * 100).round()}% of your rated verdicts were '
            'false alarms ($falseAlarms of $total). ${suggested.label} mode '
            'would flag fewer safe messages.',
        shouldSuggestChange: true,
      );
    }

    return CalibrationAdvice(
      currentMode: currentMode,
      suggestedMode: currentMode,
      reason: 'Sensitivity looks right for your traffic.',
      shouldSuggestChange: false,
    );
  }
}
