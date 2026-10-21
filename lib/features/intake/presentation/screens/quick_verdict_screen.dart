import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/threat_analysis.dart';
import '../../../../core/services/link_safety_service.dart';
import '../../../../core/services/shared_intake_service.dart';
import '../../../../core/services/threat_engine.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/threat_widgets.dart';
import '../../../sms/presentation/screens/sms_detail_screen.dart';

/// The verdict screen for messages shared in from another app.
///
/// Designed for a ~2-second read: the user is mid-conversation in WhatsApp and
/// tapped Share. They need the verdict, the reason, and what to do — nothing
/// else competes for attention. One tap expands to the full analysis.
class QuickVerdictScreen extends StatefulWidget {
  final SharedIntake intake;
  final ThreatEngine engine;
  final LinkSafetyService linkSafetyService;
  final VoidCallback onDismiss;
  final void Function(SharedIntake intake) onCheckAnother;

  const QuickVerdictScreen({
    super.key,
    required this.intake,
    required this.engine,
    required this.linkSafetyService,
    required this.onDismiss,
    required this.onCheckAnother,
  });

  @override
  State<QuickVerdictScreen> createState() => _QuickVerdictScreenState();
}

class _QuickVerdictScreenState extends State<QuickVerdictScreen> {
  late MessageThreatReport _report;

  @override
  void initState() {
    super.initState();

    _report = widget.engine.analyzeText(
      widget.intake.text,
      source: widget.intake.source,
    );

    // A verdict is the one moment where a haptic makes the result feel real.
    final highRisk = _report.analysis.finalLevel == ThreatLevel.highRisk;
    HapticFeedback.mediumImpact().catchError((_) {});

    if (highRisk) {
      // A second, heavier pulse to distinguish a warning from a safe result.
      Future<void>.delayed(
        const Duration(milliseconds: 120),
        () => HapticFeedback.heavyImpact().catchError((_) {}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final analysis = _report.analysis;
    final level = analysis.finalLevel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verdict'),
        leading: IconButton(
          onPressed: widget.onDismiss,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          TextButton(
            onPressed: () => widget.onCheckAnother(widget.intake),
            child: const Text('Check another'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          VerdictBanner(
            level: level,
            type: analysis.finalType,
            score: analysis.blendedRiskScore,
            originLabel: widget.intake.originLabel,
            unavailableReason: analysis.isAnalysed
                ? null
                : analysis.unavailableReason,
          ),
          const SizedBox(height: 14),
          _topReasons(context),
          const SizedBox(height: 14),
          _actionCard(context),
          if (widget.intake.channel.isUserInvoked) ...[
            const SizedBox(height: 14),
            _noteCard(context),
          ],
          const SizedBox(height: 14),
          EvidenceProvenanceCard(summary: analysis.evidenceSummary),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => _openFullDetail(context),
            icon: const Icon(Icons.article_outlined),
            label: const Text('See full analysis'),
          ),
        ],
      ),
    );
  }

  Widget _topReasons(BuildContext context) {
    final indicators = _report.analysis.ruleAnalysis.indicators;

    if (indicators.isEmpty) {
      return SectionCard(
        title: 'Nothing was found',
        icon: Icons.check_circle_outline,
        child: Text(
          // The final verdict's explanation, not the rule engine's: after a
          // downgrade the rule summary still talks about the threat.
          _report.analysis.summary,
          style: const TextStyle(height: 1.45),
        ),
      );
    }

    // Strongest first, and scored evidence before the explanation-only rows.
    // Taking the raw collection order showed whichever rule was catalogued
    // first, which is not the same thing as what made the verdict.
    final ordered = [...indicators]
      ..sort((a, b) => b.scoreContribution.compareTo(a.scoreContribution));

    // Only the strongest three: this screen is for a fast decision.
    final top = ordered.take(3).toList();

    return SectionCard(
      title:
          'Why (${indicators.length} indicator'
          '${indicators.length == 1 ? '' : 's'})',
      icon: Icons.fact_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final indicator in top)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.flag_outlined,
                      size: 15,
                      color: AppTheme.suspiciousColor,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          indicator.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        if (indicator.evidence != null &&
                            indicator.evidence!.isNotEmpty)
                          Text(
                            'Matched: "${indicator.evidence}"',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (indicators.length > 3)
            Text(
              '+${indicators.length - 3} more in the full analysis',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionCard(BuildContext context) {
    return SectionCard(
      title: 'What to do',
      icon: Icons.shield_outlined,
      child: Text(
        _report.analysis.ruleAnalysis.recommendation,
        style: const TextStyle(height: 1.45, fontSize: 13.5),
      ),
    );
  }

  Widget _noteCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 17,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Checked from ${widget.intake.originLabel}. ThreatGuard cannot '
                'read those apps directly, so it only sees what you share.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _QuickDetailHost(
          intake: widget.intake,
          report: _report,
          engine: widget.engine,
        ),
      ),
    );
  }
}

/// Hosts the standard detail screen for a shared message.
///
/// The detail screen expects an `InboxController` for its feedback section;
/// a shared message has no inbox, so a controller is not required and the
/// feedback card is simply absent.
class _QuickDetailHost extends StatelessWidget {
  final SharedIntake intake;
  final MessageThreatReport report;
  final ThreatEngine engine;

  const _QuickDetailHost({
    required this.intake,
    required this.report,
    required this.engine,
  });

  @override
  Widget build(BuildContext context) {
    return SmsDetailScreen(
      report: report,
      engine: engine,
      // A shared message is not part of the inbox, so there is no controller
      // to record feedback against.
      controller: null,
    );
  }
}

/// Full-bleed verdict banner: the single element the user's eye should land on.
class VerdictBanner extends StatelessWidget {
  final ThreatLevel level;
  final ThreatType type;
  final int score;
  final String? originLabel;

  /// Non-null when nothing was analysed (disabled channel, engine failure).
  ///
  /// A channel-disabled message used to render as a green "Looks safe, 0/100"
  /// banner — a chip telling the user a message they never read is fine.
  final String? unavailableReason;

  const VerdictBanner({
    super.key,
    required this.level,
    required this.type,
    required this.score,
    this.originLabel,
    this.unavailableReason,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.levelColor(level);

    final notAnalysed = unavailableReason != null;

    final headline = notAnalysed
        ? 'Not checked'
        : switch (level) {
            ThreatLevel.safe => 'Looks safe',
            ThreatLevel.suspicious => 'Be careful',
            ThreatLevel.highRisk => 'Dangerous',
          };

    final displayColor = notAnalysed
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : color;

    return Semantics(
      label: notAnalysed
          ? 'Not checked. $unavailableReason'
          : '$headline. ${AppTheme.typeLabel(type)}, risk score $score out of '
                '100.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          gradient: LinearGradient(
            colors: [
              displayColor.withValues(alpha: 0.16),
              displayColor.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: displayColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: displayColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                notAnalysed ? Icons.help_outline : AppTheme.levelIcon(level),
                size: 34,
                color: displayColor,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              headline,
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: displayColor,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              notAnalysed ? unavailableReason! : AppTheme.typeLabel(type),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!notAnalysed) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: displayColor,
                    ),
                  ),
                  Text(
                    '/100',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: displayColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
            if (originLabel != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface
                      .withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Checked from $originLabel',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
