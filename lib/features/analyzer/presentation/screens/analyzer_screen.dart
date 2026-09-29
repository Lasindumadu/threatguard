import 'package:flutter/material.dart';

import '../../../../core/models/threat_analysis.dart';
import '../../../../core/services/threat_analyzer.dart';

class AnalyzerScreen extends StatefulWidget {
  const AnalyzerScreen({super.key});

  @override
  State<AnalyzerScreen> createState() => _AnalyzerScreenState();
}

class _AnalyzerScreenState extends State<AnalyzerScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ThreatAnalyzer _analyzer = ThreatAnalyzer();

  ThreatAnalysis? _analysis;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _analyzeMessage() {
    final analysis = _analyzer.analyze(_messageController.text);

    setState(() {
      _analysis = analysis;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ThreatGuard'), centerTitle: false),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Message Threat Analyzer',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Analyze a message for common spam, scam, phishing, and social-engineering indicators.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _messageController,
                    minLines: 7,
                    maxLines: 12,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      hintText: 'Paste a message here...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _analyzeMessage,
                      icon: const Icon(Icons.security),
                      label: const Text('Analyze Message'),
                    ),
                  ),
                  if (_analysis != null) ...[
                    const SizedBox(height: 32),
                    _AnalysisCard(analysis: _analysis!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  final ThreatAnalysis analysis;

  const _AnalysisCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final levelText = switch (analysis.level) {
      ThreatLevel.safe => 'SAFE',
      ThreatLevel.suspicious => 'SUSPICIOUS',
      ThreatLevel.highRisk => 'HIGH RISK',
    };

    final typeText = switch (analysis.type) {
      ThreatType.legitimate => 'LEGITIMATE',
      ThreatType.spam => 'SPAM',
      ThreatType.phishing => 'PHISHING',
      ThreatType.scam => 'SCAM',
      ThreatType.socialEngineering => 'SOCIAL ENGINEERING',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analysis Result',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              analysis.summary,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _ResultItem(
                    label: 'Risk Score',
                    value: '${analysis.riskScore}/100',
                  ),
                ),
                Expanded(
                  child: _ResultItem(label: 'Risk Level', value: levelText),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _ResultItem(label: 'Classification', value: typeText),
            const SizedBox(height: 24),
            Text(
              'Detected Indicators',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (analysis.indicators.isEmpty)
              const Text('No specific threat indicators detected.')
            else
              ...analysis.indicators.map(
                (indicator) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              indicator.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(indicator.description),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              'Recommended Action',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(analysis.recommendation),
          ],
        ),
      ),
    );
  }
}

class _ResultItem extends StatelessWidget {
  final String label;
  final String value;

  const _ResultItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
