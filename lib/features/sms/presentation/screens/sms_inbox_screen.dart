import 'package:flutter/material.dart';

import '../../../../core/models/organization_url_check.dart';
import '../../../../core/models/sender_analysis.dart';
import '../../../../core/models/threat_analysis.dart';
import '../../../../core/models/threat_message.dart';

import '../../../../core/services/android_sms_message_source.dart';
import '../../../../core/services/hybrid_threat_analyzer.dart';
import '../../../../core/services/logistic_regression_classifier.dart';
import '../../../../core/services/ml_feature_encoder.dart';
import '../../../../core/services/ml_training_dataset.dart';
import '../../../../core/services/organization_url_analyzer.dart';
import '../../../../core/services/sender_analyzer.dart';

class SmsInboxScreen extends StatefulWidget {
  const SmsInboxScreen({super.key});

  @override
  State<SmsInboxScreen> createState() => _SmsInboxScreenState();
}

class _SmsInboxScreenState extends State<SmsInboxScreen> {
  late final HybridThreatAnalyzer _analyzer;

  final AndroidSmsMessageSource _messageSource =
      const AndroidSmsMessageSource();

  final SenderAnalyzer _senderAnalyzer = const SenderAnalyzer();

  final OrganizationUrlAnalyzer _organizationUrlAnalyzer =
      const OrganizationUrlAnalyzer();

  List<ThreatMessage> _messages = const [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    final trainingExamples = const MlTrainingDataset().build();
    final featureEncoder = const MlFeatureEncoder();

    final featureVectors = trainingExamples
        .map((example) => featureEncoder.encode(example.features))
        .toList();

    final classifier = LogisticRegressionClassifier.train(
      examples: trainingExamples,
      featureVectors: featureVectors,
    );

    _analyzer = HybridThreatAnalyzer(classifier: classifier);

    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final messages = await _messageSource.readMessages();

      if (!mounted) {
        return;
      }

      setState(() {
        _messages = messages;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Inbox'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadMessages,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh messages',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Unable to read SMS messages.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadMessages,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sms_outlined, size: 64),
              SizedBox(height: 16),
              Text(
                'No SMS messages found.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'ThreatGuard could not find any messages on this device.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMessages,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          return _buildMessageCard(_messages[index]);
        },
      ),
    );
  }

  Widget _buildMessageCard(ThreatMessage message) {
    final analysis = _analyzer.analyze(message.body);
    final ruleAnalysis = analysis.ruleAnalysis;
    final senderAnalysis = _senderAnalyzer.analyze(message.sender);

    final organizationUrlCheck = _organizationUrlAnalyzer.analyze(
      senderAnalysis: senderAnalysis,
      urls: ruleAnalysis.detectedUrls,
    );

    final level = analysis.finalLevel;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                      Text(
                        message.sender ?? 'Unknown sender',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      _buildRiskBadge(level, ruleAnalysis.riskScore),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSenderVerification(senderAnalysis),
            const SizedBox(height: 10),
            _buildOrganizationUrlVerification(organizationUrlCheck),
            const SizedBox(height: 14),
            Text(message.body, maxLines: 4, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Text(
              _classificationLabel(analysis.finalType),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSenderVerification(SenderAnalysis analysis) {
    if (analysis.verificationStatus == SenderVerificationStatus.recognized) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.blue.withValues(alpha: 0.08),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.business_outlined, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recognized organization',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(analysis.organization!),
                  const SizedBox(height: 3),
                  Text(
                    'Sender identity confidence: '
                    '${(analysis.confidence * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.withValues(alpha: 0.08),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.help_outline, size: 20),
          SizedBox(width: 10),
          Expanded(child: Text('Sender organization could not be verified.')),
        ],
      ),
    );
  }

  Widget _buildOrganizationUrlVerification(OrganizationUrlCheck check) {
    switch (check.consistency) {
      case OrganizationUrlConsistency.noUrl:
        return const SizedBox.shrink();

      case OrganizationUrlConsistency.consistent:
        return _buildVerificationBanner(
          icon: Icons.verified_outlined,
          title: 'Link matches organization',
          message:
              'The detected link matches an official domain for '
              '${check.organization}.',
        );

      case OrganizationUrlConsistency.inconsistent:
        return _buildVerificationBanner(
          icon: Icons.warning_amber_outlined,
          title: 'Link does not match organization',
          message:
              'The detected link does not match the known official '
              'domains for ${check.organization}.',
        );

      case OrganizationUrlConsistency.unknown:
        return _buildVerificationBanner(
          icon: Icons.help_outline,
          title: 'Link organization could not be verified',
          message:
              'The sender or organization could not be linked to '
              'an official domain.',
        );
    }
  }

  Widget _buildVerificationBanner({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.withValues(alpha: 0.08),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskBadge(ThreatLevel level, int score) {
    return Text(
      '${_levelLabel(level)} • $score/100',
      style: TextStyle(fontWeight: FontWeight.w600, color: _levelColor(level)),
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
