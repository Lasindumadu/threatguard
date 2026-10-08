import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/organization_url_check.dart';
import '../../../../core/models/sender_analysis.dart';
import '../../../../core/models/threat_analysis.dart';
import '../../../../core/models/threat_message.dart';

import '../../../../core/services/android_sms_message_source.dart';
import '../../../../core/services/fake_sms_message_source.dart';
import '../../../../core/services/hybrid_threat_analyzer.dart';
import '../../../../core/services/logistic_regression_classifier.dart';
import '../../../../core/services/ml_feature_encoder.dart';
import '../../../../core/services/ml_training_dataset.dart';
import '../../../../core/services/organization_url_analyzer.dart';
import '../../../../core/services/sender_analyzer.dart';
import 'sms_detail_screen.dart';

class SmsInboxScreen extends StatefulWidget {
  const SmsInboxScreen({super.key});

  @override
  State<SmsInboxScreen> createState() => _SmsInboxScreenState();
}

class _SmsInboxScreenState extends State<SmsInboxScreen> {
  static const MethodChannel _smsChannel = MethodChannel('threatguard/sms');

  late final HybridThreatAnalyzer _analyzer;

  final AndroidSmsMessageSource _messageSource =
      const AndroidSmsMessageSource();

  final FakeSmsMessageSource _demoMessageSource = const FakeSmsMessageSource();

  final SenderAnalyzer _senderAnalyzer = const SenderAnalyzer();

  final OrganizationUrlAnalyzer _organizationUrlAnalyzer =
      const OrganizationUrlAnalyzer();

  List<ThreatMessage> _messages = const [];
  bool _isLoading = false;
  bool _isDemoMode = false;
  bool _hasSmsPermission = false;
  bool _smsPermissionPermanentlyDenied = false;
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

    _initializeInbox();
  }

  Future<void> _initializeInbox() async {
    try {
      final hasPermission =
          await _smsChannel.invokeMethod<bool>('checkSmsPermission') ?? false;

      if (!mounted) {
        return;
      }

      setState(() {
        _hasSmsPermission = hasPermission;
        _smsPermissionPermanentlyDenied = false;
      });

      if (hasPermission) {
        await _loadMessages();
      }
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message ?? 'Unable to check SMS permission.';
      });
    }
  }

  Future<void> _requestSmsPermission() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final granted =
          await _smsChannel.invokeMethod<bool>('requestSmsPermission') ?? false;

      if (!mounted) {
        return;
      }

      if (granted) {
        setState(() {
          _hasSmsPermission = true;
          _smsPermissionPermanentlyDenied = false;
          _isLoading = false;
        });

        await _loadMessages();
        return;
      }

      final permanentlyDenied =
          await _smsChannel.invokeMethod<bool>(
            'isSmsPermissionPermanentlyDenied',
          ) ??
          false;

      if (!mounted) {
        return;
      }

      setState(() {
        _hasSmsPermission = false;
        _smsPermissionPermanentlyDenied = permanentlyDenied;
        _isLoading = false;
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.message ?? 'Unable to request SMS permission.';
      });
    }
  }

  Future<void> _openAppSettings() async {
    try {
      await _smsChannel.invokeMethod<void>('openAppSettings');
    } on PlatformException {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Unable to open app settings.';
      });
    }
  }

  Future<void> _loadMessages() async {
    if (!_hasSmsPermission) {
      return;
    }

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
        _isDemoMode = false;
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.message ?? 'Unable to read SMS messages.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to read SMS messages.';
      });
    }
  }

  Future<void> _loadDemoMessages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final messages = await _demoMessageSource.readMessages();

      if (!mounted) {
        return;
      }

      setState(() {
        _messages = messages;
        _isLoading = false;
        _isDemoMode = true;
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
            onPressed: _isLoading ? null : _loadDemoMessages,
            icon: const Icon(Icons.science_outlined),
            tooltip: 'Load demo messages',
          ),
          IconButton(
            onPressed: _isLoading || !_hasSmsPermission ? null : _loadMessages,
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
              if (!_hasSmsPermission) ...[
                if (_smsPermissionPermanentlyDenied)
                  OutlinedButton.icon(
                    onPressed: _openAppSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Open App Settings'),
                  )
                else
                  FilledButton.icon(
                    onPressed: _requestSmsPermission,
                    icon: const Icon(Icons.sms_outlined),
                    label: const Text('Allow SMS Access'),
                  ),
              ] else
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

    if (!_hasSmsPermission && !_isDemoMode) {
      return _buildPermissionRequest();
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
        itemCount: _messages.length + (_isDemoMode ? 1 : 0),
        itemBuilder: (context, index) {
          if (_isDemoMode && index == 0) {
            return _buildDemoModeBanner();
          }

          final messageIndex = _isDemoMode ? index - 1 : index;
          return _buildMessageCard(_messages[messageIndex]);
        },
      ),
    );
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sms_outlined, size: 64),
            const SizedBox(height: 20),
            const Text(
              'SMS Access Required',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'ThreatGuard needs access to your SMS messages '
              'so it can analyze them for phishing, scams, spam, '
              'and social engineering threats.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_smsPermissionPermanentlyDenied) ...[
              const Text(
                'SMS access has been permanently denied. '
                'Open App Settings to allow SMS access manually.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _openAppSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Open App Settings'),
              ),
            ] else
              FilledButton.icon(
                onPressed: _requestSmsPermission,
                icon: const Icon(Icons.lock_open_outlined),
                label: const Text('Allow SMS Access'),
              ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadDemoMessages,
              child: const Text('Use Demo Messages Instead'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoModeBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.amber.withValues(alpha: 0.12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Demo Mode',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 3),
                Text(
                  'These are simulated messages for testing. '
                  'Tap Refresh to return to your real SMS inbox.',
                ),
              ],
            ),
          ),
        ],
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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SmsDetailScreen(
                message: message,
                analysis: analysis,
                senderAnalysis: senderAnalysis,
                organizationUrlCheck: organizationUrlCheck,
              ),
            ),
          );
        },
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
                        if (message.receivedAt != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _formatReceivedAt(context, message.receivedAt!),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        _buildRiskBadge(level, ruleAnalysis.riskScore),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
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
