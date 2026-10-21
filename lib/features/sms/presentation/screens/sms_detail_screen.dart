import 'package:flutter/material.dart';

import '../../../../core/models/hybrid_threat_analysis.dart';
import '../../../../core/models/ml_feature_vector.dart';
import '../../../../core/models/organization_url_check.dart';
import '../../../../core/models/sender_analysis.dart';
import '../../../../core/models/threat_analysis.dart';
import '../../../../core/services/local_store.dart';
import '../../../../core/services/threat_engine.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/threat_widgets.dart';
import '../../application/inbox_controller.dart';

/// Full explanation of one message's verdict.
///
/// The governing idea: a user (or a security reviewer) should be able to see
/// *exactly* why this message got this label — the matched text, the weighted
/// rule contributions, the model's probability distribution, and which engine
/// was the tie-breaker.
class SmsDetailScreen extends StatefulWidget {
  final MessageThreatReport report;
  final ThreatEngine engine;

  /// Null when the message was shared in rather than read from the inbox, in
  /// which case there is no inbox to record feedback against.
  final InboxController? controller;

  const SmsDetailScreen({
    super.key,
    required this.report,
    required this.engine,
    this.controller,
  });

  @override
  State<SmsDetailScreen> createState() => _SmsDetailScreenState();
}

class _SmsDetailScreenState extends State<SmsDetailScreen> {
  bool _showTechnicalDetail = false;

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final analysis = report.analysis;
    final level = analysis.finalLevel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Threat analysis'),
        actions: [
          IconButton(
            tooltip: _showTechnicalDetail
                ? 'Hide technical detail'
                : 'Show technical detail',
            onPressed: () =>
                setState(() => _showTechnicalDetail = !_showTechnicalDetail),
            icon: Icon(
              _showTechnicalDetail
                  ? Icons.visibility_off_outlined
                  : Icons.code_outlined,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _verdictCard(context, report, level),
          const SizedBox(height: 14),
          _recommendationCard(context, analysis),
          const SizedBox(height: 14),
          // What we know / inferred / don't know. Phase 1: the full detail
          // screen showed evidence and scores but never said which parts were
          // observed, which were inferred, and what the app could not check.
          EvidenceProvenanceCard(
            summary: analysis.evidenceSummaryWithSender(
              senderShortCodeUnregistered: report.senderShortCodeUnregistered,
              sender: report.message.sender,
            ),
          ),
          const SizedBox(height: 14),
          _messageCard(context, report),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Model confidence',
            icon: Icons.insights_outlined,
            child: ProbabilityBreakdown(analysis: analysis),
          ),
          const SizedBox(height: 14),
          _senderCard(context, report.senderAnalysis),
          if (report.organizationUrlCheck.consistency !=
              OrganizationUrlConsistency.noUrl) ...[
            const SizedBox(height: 14),
            _organizationUrlCard(context, report.organizationUrlCheck),
          ],
          const SizedBox(height: 14),
          _indicatorsCard(context, analysis),
          if (report.templateMatch?.isCampaign ?? false) ...[
            const SizedBox(height: 14),
            _campaignCard(context, report),
          ],
          const SizedBox(height: 14),
          _feedbackCard(context),
          if (_showTechnicalDetail) ...[
            const SizedBox(height: 14),
            _technicalCard(context, analysis),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------- verdict

  Widget _verdictCard(
    BuildContext context,
    MessageThreatReport report,
    ThreatLevel level,
  ) {
    final analysis = report.analysis;
    final color = AppTheme.levelColor(level);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            RiskGauge(score: analysis.blendedRiskScore, level: level),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                AppTheme.levelLabel(level).toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  fontSize: 12.5,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppTheme.typeLabel(analysis.finalType),
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              // The final verdict's own explanation: the rule verdict's summary
              // is computed before arbitration and can contradict the verdict
              // shown above it.
              analysis.summary,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            _verdictSourceRow(context, analysis),
            const SizedBox(height: 12),
            _confidenceRow(context, analysis),
          ],
        ),
      ),
    );
  }

  /// Says how sure this verdict is, in the taxonomy the product uses.
  ///
  /// The risk score is an additive index, not a probability, so it is never
  /// shown as one. Three facts are separated here: how much risk there is,
  /// how confident the verdict is, and whether the app could even check the
  /// sender.
  Widget _confidenceRow(
    BuildContext context,
    HybridThreatAnalysis analysis,
  ) {
    if (!analysis.isAnalysed) {
      return Row(
        children: [
          const Icon(Icons.help_outline, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              analysis.unavailableReason!,
              style: const TextStyle(fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      );
    }

    final confidence = analysis.evidenceConfidence;
    final (label, note) = switch (confidence) {
      EvidenceConfidence.benign => (
        'No threat evidence',
        'Nothing matched. That is not a guarantee the sender is genuine.',
      ),
      EvidenceConfidence.suspicious => (
        'Suspicious, not proven',
        'Some warning signs are present. Treat this as a reason to check, '
            'not as proof of an attack.',
      ),
      EvidenceConfidence.highRisk => (
        'High risk, inferred',
        'The wording and link structure match a known attack shape. Matched '
            'phrases and structure cannot prove intent.',
      ),
      EvidenceConfidence.confirmedThreat => (
        'Confirmed threat',
        'Only an external report or the recipient can confirm an attack.',
      ),
    };

    final percent = (analysis.verdictConfidence * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            analysis.isThreat ? '$label — confidence $percent%' : label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Risk score ${analysis.blendedRiskScore}/100 is an index, not a '
            'probability that the sender is malicious.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Explains which engine decided, in plain language.
  Widget _verdictSourceRow(BuildContext context, HybridThreatAnalysis analysis) {
    final (label, icon) = switch (analysis.source) {
      VerdictSource.consensus => (
        'Rules and model agree',
        Icons.handshake_outlined,
      ),
      VerdictSource.machineLearning => (
        'Decided by the model',
        Icons.memory_outlined,
      ),
      VerdictSource.ruleEngine => ('Decided by rules', Icons.rule_outlined),
      VerdictSource.modelOverride => (
        'Model overruled weak rules',
        Icons.tune_outlined,
      ),
      VerdictSource.externalReport => (
        'Reported by a trusted source',
        Icons.report_outlined,
      ),
      VerdictSource.none => ('No signal found', Icons.check_circle_outline),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (analysis.rationale.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              analysis.rationale,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------ recommendation

  Widget _recommendationCard(
    BuildContext context,
    HybridThreatAnalysis analysis,
  ) {
    final level = analysis.finalLevel;
    final color = AppTheme.levelColor(level);
    final isThreat = analysis.isThreat;

    final actions = switch (analysis.finalType) {
      ThreatType.phishing => const [
        'Do not enter any password, OTP, PIN or card number.',
        'Do not tap links in this message.',
        'Contact the organisation using a number you look up yourself.',
      ],
      ThreatType.scam => const [
        'Do not send money or share financial details.',
        'Verify the offer independently before acting.',
        'Report the message to your carrier as spam.',
      ],
      ThreatType.socialEngineering => const [
        'Do not reply or share information under pressure.',
        'Verify the request through a trusted, separate channel.',
        'Be wary of secrecy or urgency used to rush you.',
      ],
      ThreatType.spam => const [
        'Ignore or block the sender.',
        'Do not reply, which confirms your number is active.',
      ],
      ThreatType.legitimate => const [
        'No action needed.',
        'Still verify unexpected requests independently.',
      ],
    };

    return SectionCard(
      title: 'What you should do',
      icon: Icons.shield_outlined,
      trailing: TypeBadge(type: analysis.finalType, compact: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            analysis.ruleAnalysis.recommendation,
            style: const TextStyle(height: 1.45),
          ),
          const SizedBox(height: 12),
          for (final action in actions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      isThreat
                          ? Icons.close_rounded
                          : Icons.check_circle_outline,
                      size: 15,
                      color: isThreat ? color : AppTheme.safeColor,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      action,
                      style: const TextStyle(fontSize: 13.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- message

  Widget _messageCard(BuildContext context, MessageThreatReport report) {
    final receivedAt = report.message.receivedAt;

    return SectionCard(
      title: 'Message',
      icon: Icons.sms_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  report.message.sender ?? 'Unknown sender',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (receivedAt != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 15),
                const SizedBox(width: 6),
                Text(
                  _formatTimestamp(receivedAt),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 22),
          Text(
            report.message.body,
            style: const TextStyle(fontSize: 14.5, height: 1.5),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- sender

  Widget _senderCard(BuildContext context, SenderAnalysis sender) {
    final recognized =
        sender.verificationStatus == SenderVerificationStatus.recognized;

    return SectionCard(
      title: 'Sender identity',
      icon: recognized ? Icons.business_outlined : Icons.help_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recognized
                ? 'Sender name matches a known organisation.'
                : 'This sender could not be matched to a known organisation.',
            style: const TextStyle(fontSize: 13.5, height: 1.4),
          ),
          if (recognized) ...[
            const SizedBox(height: 6),
            Text(
              sender.organization!,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 8),
          // Sender-id spoofing is trivial, so this caveat is load-bearing.
          Text(
            'Sender names can be spoofed. A matching name does not prove the '
            'message is genuine.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _organizationUrlCard(BuildContext context, OrganizationUrlCheck check) {
    final (icon, title, message) = switch (check.consistency) {
      OrganizationUrlConsistency.consistent => (
        Icons.verified_outlined,
        'Link matches organisation',
        'The link uses a domain associated with ${check.organization}. This '
            'does not by itself make the link safe.',
      ),
      OrganizationUrlConsistency.inconsistent => (
        Icons.gpp_bad_outlined,
        'Link does not match organisation',
        'The link does not use a known official domain for '
            '${check.organization}. Treat this as a strong warning sign.',
      ),
      OrganizationUrlConsistency.unknown => (
        Icons.help_outline,
        'Link could not be verified',
        'The link could not be tied to an official domain.',
      ),
      OrganizationUrlConsistency.noUrl => (
        Icons.link_off,
        'No link',
        'This message contains no links.',
      ),
    };

    return SectionCard(
      title: 'Link check',
      icon: icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
          const SizedBox(height: 4),
          Text(message, style: const TextStyle(height: 1.4)),
          if (check.url != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                check.url!,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ----------------------------------------------------------- campaigns

  Widget _campaignCard(BuildContext context, MessageThreatReport report) {
    final match = report.templateMatch!;

    return SectionCard(
      title: 'Campaign detected',
      icon: Icons.content_copy_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This message matches a template seen ${match.occurrences} '
            '${match.occurrences == 1 ? 'time' : 'times'} in your scanned '
            'messages. Mass-campaign messages are almost always unwanted.',
            style: const TextStyle(height: 1.45),
          ),
          if (match.sample != null) ...[
            const SizedBox(height: 10),
            Text(
              'Representative message',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              match.sample!,
              style: TextStyle(
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------- indicators

  Widget _indicatorsCard(BuildContext context, HybridThreatAnalysis analysis) {
    final indicators = analysis.ruleAnalysis.indicators;
    final detectedUrls = analysis.ruleAnalysis.detectedUrls;

    return SectionCard(
      title: 'Evidence (${indicators.length + detectedUrls.length})',
      icon: Icons.fact_check_outlined,
      child: indicators.isEmpty && detectedUrls.isEmpty
          ? const Text('No specific threat indicators were detected.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final indicator in indicators)
                  _indicatorTile(context, indicator),
                if (detectedUrls.isNotEmpty) ...[
                  const Divider(height: 20),
                  Text(
                    'Links found in this message',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final url in detectedUrls)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.link, size: 14),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              url,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _indicatorTile(BuildContext context, ThreatIndicator indicator) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppTheme.suspiciousColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.flag_outlined,
              size: 14,
              color: AppTheme.suspiciousColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        indicator.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    if (indicator.scoreContribution > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.suspiciousColor.withValues(
                            alpha: 0.14,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+${indicator.scoreContribution}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.suspiciousColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  indicator.description,
                  style: const TextStyle(fontSize: 12.5, height: 1.4),
                ),
                if (indicator.evidence != null &&
                    indicator.evidence!.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    'Matched: "${indicator.evidence}"',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  // ------------------------------------------------------------- feedback

  Widget _feedbackCard(BuildContext context) {
    final store = widget.controller?.store;

    // No inbox controller means this message was shared in from another app;
    // there is no inbox entry to attach feedback to.
    if (store == null) {
      return const SizedBox.shrink();
    }

    return SectionCard(
      title: 'Was this correct?',
      icon: Icons.rate_review_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your feedback stays on this device and can be exported as a '
            'labelled training set.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _recordFeedback(UserFeedback.confirmed),
                icon: const Icon(Icons.thumb_up_outlined, size: 16),
                label: const Text('Correct'),
              ),
              OutlinedButton.icon(
                onPressed: () => _recordFeedback(UserFeedback.falseAlarm),
                icon: const Icon(Icons.thumb_down_outlined, size: 16),
                label: const Text('False alarm'),
              ),
              OutlinedButton.icon(
                onPressed: () => _recordFeedback(UserFeedback.missed),
                icon: const Icon(Icons.report_outlined, size: 16),
                label: const Text('Missed a threat'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _recordFeedback(UserFeedback feedback) async {
    final store = widget.controller?.store;
    if (store == null) return;

    final report = widget.report;

    await store.addFeedback(
      FeedbackEntry(
        messageId: report.message.id,
        messageBody: report.message.body,
        sender: report.message.sender,
        predictedType: report.analysis.finalType,
        feedback: feedback,
        recordedAt: DateTime.now(),
      ),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Feedback recorded. Thank you.')),
    );
  }

  // ------------------------------------------------------------ technical

  Widget _technicalCard(BuildContext context, HybridThreatAnalysis analysis) {
    final ml = analysis.mlPrediction;

    return SectionCard(
      title: 'Technical detail',
      icon: Icons.code_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv('Rule score', '${analysis.ruleAnalysis.riskScore}/100'),
          _kv('Blended score', '${analysis.blendedRiskScore}/100'),
          _kv('Rule verdict', analysis.ruleAnalysis.type.name),
          _kv('Model verdict', _mlLabel(ml.type)),
          _kv(
            'Model confidence',
            '${(ml.confidence * 100).toStringAsFixed(1)}%',
          ),
          _kv('Top-2 margin', '${(ml.margin * 100).toStringAsFixed(1)}%'),
          _kv('Decided by', analysis.source.name),
          _kv(
            'Engine agreement',
            '${(analysis.agreement * 100).toStringAsFixed(0)}%',
          ),
          _kv('Indicators', '${analysis.ruleAnalysis.indicators.length}'),
          _kv('URLs', '${analysis.ruleAnalysis.detectedUrls.length}'),
        ],
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              key,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _mlLabel(MlThreatType type) => switch (type) {
    MlThreatType.legitimate => 'legitimate',
    MlThreatType.spam => 'spam',
    MlThreatType.phishing => 'phishing',
    MlThreatType.scam => 'scam',
    MlThreatType.socialEngineering => 'socialEngineering',
  };

  String _formatTimestamp(DateTime date) {
    final local = date.toLocal();

    String two(int value) => value.toString().padLeft(2, '0');

    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
