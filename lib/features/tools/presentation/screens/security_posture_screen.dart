import 'package:flutter/material.dart';

import '../../../../core/models/security_posture.dart';
import '../../../../core/models/threat_analysis.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/threat_widgets.dart';

/// Device security hygiene checklist.
class SecurityPostureScreen extends StatefulWidget {
  final SecurityPosture posture;

  const SecurityPostureScreen({
    super.key,
    this.posture = const SecurityPosture(checks: []),
  });

  @override
  State<SecurityPostureScreen> createState() => _SecurityPostureScreenState();
}

class _SecurityPostureScreenState extends State<SecurityPostureScreen> {
  late SecurityPosture _posture;

  @override
  void initState() {
    super.initState();

    // A supplied posture is used as-is; otherwise assess with the values a
    // screen can actually know without platform calls, marking the rest
    // unknown rather than guessing.
    _posture = widget.posture.checks.isEmpty
        ? const SecurityPostureAssessor().assess(
            screenLockEnabled: null,
            smsPermissionGranted: null,
            onlineLookupEnabled: false,
            strictModeEnabled: false,
            mutedSenderCount: 0,
            feedbackGiven: 0,
            scannedMessages: 0,
            highRiskMessages: 0,
          )
        : widget.posture;
  }

  @override
  Widget build(BuildContext context) {
    final failures = _posture.failures;

    return Scaffold(
      appBar: AppBar(title: const Text('Device posture')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _scoreCard(context),
          if (failures.isNotEmpty) ...[
            const SizedBox(height: 14),
            SectionCard(
              title: 'Fix these first (${failures.length})',
              icon: Icons.build_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final check in failures) _checkTile(context, check),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SectionCard(
            title: 'All checks',
            icon: Icons.checklist_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final check in _posture.checks.where(
                  (c) => !failures.contains(c),
                ))
                  _checkTile(context, check),
              ],
            ),
          ),
          if (_posture.unknownCount > 0) ...[
            const SizedBox(height: 14),
            _honestyCard(context),
          ],
        ],
      ),
    );
  }

  Widget _scoreCard(BuildContext context) {
    final color = switch (_posture.grade) {
      PostureGrade.strong => AppTheme.safeColor,
      PostureGrade.good => AppTheme.safeColor,
      PostureGrade.weak => AppTheme.suspiciousColor,
      PostureGrade.poor => AppTheme.highRiskColor,
    };

    final label = switch (_posture.grade) {
      PostureGrade.strong => 'Strong',
      PostureGrade.good => 'Good',
      PostureGrade.weak => 'Needs work',
      PostureGrade.poor => 'Poor',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            RiskGauge(
              score: _posture.score,
              level: _posture.score >= 70
                  ? ThreatLevel.safe
                  : _posture.score >= 45
                  ? ThreatLevel.suspicious
                  : ThreatLevel.highRisk,
            ),
            const SizedBox(height: 14),
            Text(
              'Device hygiene: $label',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Scored across the checks that could actually be evaluated on '
              'this device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkTile(BuildContext context, PostureCheck check) {
    final (icon, color) = switch (check.status) {
      PostureStatus.pass => (Icons.check_circle_outline, AppTheme.safeColor),
      PostureStatus.warning => (Icons.info_outline, AppTheme.suspiciousColor),
      PostureStatus.fail => (Icons.error_outline, AppTheme.highRiskColor),
      PostureStatus.unknown => (
        Icons.help_outline,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  check.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  check.description,
                  style: const TextStyle(fontSize: 12.5, height: 1.45),
                ),
                if (check.remediation != null &&
                    check.status != PostureStatus.pass) ...[
                  const SizedBox(height: 7),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Text(
                      check.remediation!,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// States plainly what could not be measured. Claiming a pass on an
  /// unobservable check would be a lie the user might rely on.
  Widget _honestyCard(BuildContext context) {
    return SectionCard(
      title: 'What ThreatGuard cannot check',
      icon: Icons.visibility_off_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_posture.unknownCount} checks could not be evaluated on this '
            'device. Android does not let a normal app read these settings, so '
            'they are reported as unknown rather than assumed safe.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          for (final check in _posture.unknowns)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• ${check.title}',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }
}
