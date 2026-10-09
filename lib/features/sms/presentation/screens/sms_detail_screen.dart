import 'package:flutter/material.dart';

import '../../../../core/models/hybrid_threat_analysis.dart';
import '../../../../core/models/organization_url_check.dart';
import '../../../../core/models/sender_analysis.dart';
import '../../../../core/models/threat_analysis.dart';
import '../../../../core/models/threat_message.dart';

class SmsDetailScreen extends StatelessWidget {
  final ThreatMessage message;
  final HybridThreatAnalysis analysis;
  final SenderAnalysis senderAnalysis;
  final OrganizationUrlCheck organizationUrlCheck;

  const SmsDetailScreen({
    super.key,
    required this.message,
    required this.analysis,
    required this.senderAnalysis,
    required this.organizationUrlCheck,
  });

  @override
  Widget build(BuildContext context) {
    final ruleAnalysis = analysis.ruleAnalysis;
    final level = analysis.finalLevel;

    return Scaffold(
      appBar: AppBar(title: const Text('SMS Threat Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewCard(level, ruleAnalysis.riskScore),
            const SizedBox(height: 16),
            _buildMessageCard(context),
            const SizedBox(height: 16),
            _buildSenderCard(),
            const SizedBox(height: 16),
            _buildOrganizationUrlCard(),
            const SizedBox(height: 16),
            _buildIndicatorsCard(),
            const SizedBox(height: 16),
            _buildRecommendationCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(ThreatLevel level, int score) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Icon(_iconForLevel(level))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Threat Assessment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_levelLabel(level)} • $score/100',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _levelColor(level),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Classification',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              _classificationLabel(analysis.finalType),
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Message',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (message.receivedAt != null) ...[
              Row(
                children: [
                  const Icon(Icons.access_time, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _formatReceivedAt(context, message.receivedAt!),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Text(
              message.body,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  String _formatReceivedAt(BuildContext context, DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now();

    if (DateUtils.isSameDay(localDate, now)) {
      return MaterialLocalizations.of(context)
          .formatTimeOfDay(TimeOfDay.fromDateTime(localDate));
    }

    final yesterday = now.subtract(const Duration(days: 1));

    if (DateUtils.isSameDay(localDate, yesterday)) {
      return 'Yesterday';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[localDate.month - 1]} '
        '${localDate.day}, ${localDate.year}';
  }

  Widget _buildSenderCard() {
    final recognized =
        senderAnalysis.verificationStatus ==
        SenderVerificationStatus.recognized;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sender Verification',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(recognized ? Icons.business_outlined : Icons.help_outline),
                const SizedBox(width: 10),
                Expanded(
                  child: recognized
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sender name matches organization',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(senderAnalysis.organization!),
                            const SizedBox(height: 6),
                            Text(
                              'Sender names can be spoofed. This match does not verify the sender.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Sender organization could not be verified.',
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizationUrlCard() {
    switch (organizationUrlCheck.consistency) {
      case OrganizationUrlConsistency.noUrl:
        return const SizedBox.shrink();

      case OrganizationUrlConsistency.consistent:
        return _buildInfoCard(
          icon: Icons.verified_outlined,
          title: 'Link matches organization',
          message:
              'The detected link matches an official domain for '
              '${organizationUrlCheck.organization}.',
        );

      case OrganizationUrlConsistency.inconsistent:
        return _buildInfoCard(
          icon: Icons.warning_amber_outlined,
          title: 'Link does not match organization',
          message:
              'The detected link does not match the known official '
              'domains for ${organizationUrlCheck.organization}.',
        );

      case OrganizationUrlConsistency.unknown:
        return _buildInfoCard(
          icon: Icons.help_outline,
          title: 'Link organization could not be verified',
          message:
              'The sender or organization could not be linked to '
              'an official domain.',
        );
    }
  }

  Widget _buildIndicatorsCard() {
    final indicators = analysis.ruleAnalysis.indicators;

    if (indicators.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.check_circle_outline),
              SizedBox(width: 10),
              Expanded(
                child: Text('No specific threat indicators were detected.'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detected Threat Indicators',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...indicators.map(
              (indicator) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_outlined, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            indicator.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 3),
                          Text(indicator.description),
                          if (indicator.scoreContribution != 0) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Score contribution: '
                              '+${indicator.scoreContribution}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recommendation',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    analysis.ruleAnalysis.recommendation,
                    style: const TextStyle(height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _levelLabel(ThreatLevel level) {
    switch (level) {
      case ThreatLevel.safe:
        return 'Safe';
      case ThreatLevel.suspicious:
        return 'Suspicious';
      case ThreatLevel.highRisk:
        return 'High Risk';
    }
  }

  String _classificationLabel(ThreatType type) {
    switch (type) {
      case ThreatType.legitimate:
        return 'Legitimate';
      case ThreatType.spam:
        return 'Spam';
      case ThreatType.phishing:
        return 'Phishing';
      case ThreatType.scam:
        return 'Scam';
      case ThreatType.socialEngineering:
        return 'Social Engineering';
    }
  }

  IconData _iconForLevel(ThreatLevel level) {
    switch (level) {
      case ThreatLevel.safe:
        return Icons.check;
      case ThreatLevel.suspicious:
        return Icons.warning_amber;
      case ThreatLevel.highRisk:
        return Icons.dangerous;
    }
  }

  Color _levelColor(ThreatLevel level) {
    switch (level) {
      case ThreatLevel.safe:
        return Colors.green;
      case ThreatLevel.suspicious:
        return Colors.orange;
      case ThreatLevel.highRisk:
        return Colors.red;
    }
  }
}
