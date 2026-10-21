import 'package:flutter/material.dart';

import '../../../../core/models/security_posture.dart';
import '../../../../core/models/threat_analysis.dart';
import '../../../../core/models/threat_message.dart';
import '../../../../core/services/compound_security_score.dart';
import '../../../../core/services/threat_engine.dart';
import '../../../../core/services/threat_trend.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/threat_widgets.dart';

/// The security posture view: one compound score, then the detail behind it.
class DashboardScreen extends StatelessWidget {
  final List<ThreatMessage> messages;
  final ThreatEngine engine;
  final SecurityPosture posture;
  final VoidCallback onScanRequested;
  final VoidCallback onOpenTools;
  final void Function(MessageThreatReport report) onOpenMessage;
  final bool isScanning;
  final String? statusMessage;

  const DashboardScreen({
    super.key,
    required this.messages,
    required this.engine,
    required this.posture,
    required this.onScanRequested,
    required this.onOpenTools,
    required this.onOpenMessage,
    this.isScanning = false,
    this.statusMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return EmptyState(
        icon: Icons.shield_outlined,
        title: isScanning ? 'Scanning your messages' : 'Nothing scanned yet',
        message:
            statusMessage ??
            'ThreatGuard reads your SMS on-device and flags phishing, scams, '
                'spam and social engineering. Messages from WhatsApp, '
                'Messenger, Instagram or any other app can be sent to '
                'ThreatGuard through the share sheet. Nothing you check ever '
                'leaves your phone.',
        actions: [
          FilledButton.icon(
            onPressed: isScanning ? null : onScanRequested,
            icon: isScanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(isScanning ? 'Scanning…' : 'Scan my messages'),
          ),
          OutlinedButton.icon(
            onPressed: onOpenTools,
            icon: const Icon(Icons.widgets_outlined),
            label: const Text('Browse security tools'),
          ),
        ],
      );
    }

    final reports = engine.analyzeAll(messages);
    final trend = ThreatTrend.fromReports(reports);
    final score = CompoundSecurityScore.compute(
      reports: reports,
      posture: posture,
    );
    final worst = ThreatTrend.highestRisk(reports, limit: 4);
    final threats = reports.where((r) => r.analysis.isThreat).toList();

    return RefreshIndicator(
      onRefresh: () async => onScanRequested(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          SecurityScoreHero(
            score: score.overall,
            headline: score.headline,
            advice: score.advice,
            highRiskCount: trend.highRisk,
            suspiciousCount: trend.suspicious,
          ),
          const SizedBox(height: 14),
          _scoreBreakdown(context, score),
          const SizedBox(height: 16),
          _statsRow(context, trend),
          const SizedBox(height: 16),
          if (threats.isNotEmpty) ...[
            SectionCard(
              title: 'Threat breakdown',
              icon: Icons.donut_small_outlined,
              child: Column(
                children: [
                  for (final type in ThreatType.values)
                    if (type != ThreatType.legitimate &&
                        (trend.byType[type] ?? 0) > 0)
                      MetricBar(
                        label: AppTheme.typeLabel(type),
                        value: (trend.byType[type] ?? 0) / reports.length,
                        color: AppTheme.typeColor(type),
                        trailing: '${trend.byType[type]}',
                      ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (trend.topThreatSenders.isNotEmpty) ...[
            SectionCard(
              title: 'Most reported senders',
              icon: Icons.person_search_outlined,
              child: Column(
                children: [
                  for (final entry in trend.topThreatSenders.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          const Icon(Icons.sms_outlined, size: 16),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.highRiskColor.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${entry.value}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.highRiskColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          SectionCard(
            title: 'Highest risk messages',
            icon: Icons.priority_high_rounded,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                for (final report in worst)
                  _WorstMessageTile(
                    report: report,
                    onTap: () => onOpenMessage(report),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'All analysis runs on this device.\n'
              'No message content is uploaded anywhere.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows what the composite is made of, so a single number never hides the
  /// detail behind it.
  Widget _scoreBreakdown(BuildContext context, CompoundSecurityScore score) {
    return SectionCard(
      title: 'What makes up your score',
      icon: Icons.donut_large_outlined,
      child: Column(
        children: [
          MetricBar(
            label: 'Message safety',
            value: score.messageRisk / 100,
            color: _tone(score.messageRisk),
            trailing: '${score.messageRisk}',
          ),
          MetricBar(
            label: 'Link exposure',
            value: score.linkExposure / 100,
            color: _tone(score.linkExposure),
            trailing: '${score.linkExposure}',
          ),
          MetricBar(
            label: 'Account hygiene',
            value: score.accountHygiene / 100,
            color: _tone(score.accountHygiene),
            trailing: '${score.accountHygiene}',
          ),
          MetricBar(
            label: 'Device posture',
            value: score.devicePosture / 100,
            color: _tone(score.devicePosture),
            trailing: '${score.devicePosture}',
          ),
        ],
      ),
    );
  }

  static Color _tone(int value) => value >= 70
      ? AppTheme.safeColor
      : value >= 45
      ? AppTheme.suspiciousColor
      : AppTheme.highRiskColor;

  Widget _statsRow(BuildContext context, ThreatTrend trend) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Scanned',
            value: '${trend.total}',
            icon: Icons.mark_email_read_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: 'High risk',
            value: '${trend.highRisk}',
            icon: Icons.gpp_maybe_rounded,
            color: AppTheme.highRiskColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: 'Suspicious',
            value: '${trend.suspicious}',
            icon: Icons.warning_amber_rounded,
            color: AppTheme.suspiciousColor,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorstMessageTile extends StatelessWidget {
  final MessageThreatReport report;
  final VoidCallback onTap;

  const _WorstMessageTile({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final analysis = report.analysis;
    final level = analysis.finalLevel;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.levelColor(level),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          report.message.sender ?? 'Unknown sender',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TypeBadge(type: analysis.finalType, compact: true),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.message.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  RiskChip(score: analysis.blendedRiskScore, level: level),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
