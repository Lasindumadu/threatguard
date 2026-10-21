import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/hybrid_threat_analysis.dart';
import '../../../../core/services/threat_engine.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/threat_widgets.dart';

/// Paste-and-analyse screen, for messages that are not in the SMS inbox
/// (e-mails, WhatsApp, chat, screenshots transcribed by hand).
///
/// This screen existed before but was unreachable: `main.dart` had its import
/// commented out, so the entire manual-analysis feature was dead code.
class AnalyzerScreen extends StatefulWidget {
  final ThreatEngine engine;

  const AnalyzerScreen({super.key, required this.engine});

  @override
  State<AnalyzerScreen> createState() => _AnalyzerScreenState();
}

class _AnalyzerScreenState extends State<AnalyzerScreen> {
  final TextEditingController _controller = TextEditingController();

  HybridThreatAnalysis? _analysis;
  String _analysedText = '';

  static const _samples = <String, String>{
    'Phishing SMS':
        'Your account has been suspended due to unusual activity. Verify your '
            'password immediately at http://secure-verify-login.top to restore '
            'access.',
    'Delivery scam':
        'Your parcel is held at customs. Pay the release fee of Rs. 250 within '
            '24 hours at http://dhl-fee-collect.top or the package will be '
            'returned.',
    'Prize scam':
        'Congratulations! You have won a cash prize of Rs. 500,000 in our '
            'lottery. Send your bank account number and a processing fee to '
            'claim now.',
    'Social engineering':
        'This is the bank security team. Keep this confidential. You must '
            'verify your identity urgently and provide your OTP to the officer '
            'before 6pm today.',
    'Legitimate':
        'Hi, your appointment is confirmed for Friday at 2 PM. Please bring '
            'your previous test results. Reply if you need to reschedule.',
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _analyze() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter or paste a message first.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    // Goes through the engine, not the bare analyzer: this path used to
    // bypass the protection mode, the channel weighting, the memoisation and
    // the benign-context check, so a manual paste could produce a different
    // verdict from the same text shared in from WhatsApp.
    final report = widget.engine.analyzeText(text);

    setState(() {
      _analysedText = text;
      _analysis = report.analysis;
    });
  }

  void _loadSample(String text) {
    _controller.text = text;
    setState(() {
      _analysis = null;
      _analysedText = '';
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;

    if (text == null || text.isEmpty) return;

    setState(() => _controller.text = text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Check any message',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Paste a text, e-mail or chat message to see whether it looks like '
            'phishing, a scam, spam or social engineering. Analysis runs '
            'entirely on this device.',
            style: TextStyle(
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Message text',
              hintText: 'Paste the message you want to check…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _analyze,
                  icon: const Icon(Icons.shield_outlined),
                  label: const Text('Analyse message'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _paste,
                icon: const Icon(Icons.content_paste),
                label: const Text('Paste'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Try an example',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final sample in _samples.entries)
                ActionChip(
                  label: Text(sample.key),
                  onPressed: () => _loadSample(sample.value),
                ),
            ],
          ),
          if (_analysis != null) ...[
            const SizedBox(height: 24),
            _resultCard(context, _analysis!),
          ],
        ],
      ),
    );
  }

  Widget _resultCard(BuildContext context, HybridThreatAnalysis analysis) {
    final level = analysis.finalLevel;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                RiskGauge(score: analysis.blendedRiskScore, level: level),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TypeBadge(type: analysis.finalType),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  analysis.summary,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.45,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                _sourceNote(context, analysis),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Model confidence',
          icon: Icons.insights_outlined,
          child: ProbabilityBreakdown(analysis: analysis),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'What you should do',
          icon: Icons.shield_outlined,
          child: Text(
            analysis.ruleAnalysis.recommendation,
            style: const TextStyle(height: 1.45),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title:
              'Evidence (${analysis.ruleAnalysis.indicators.length})',
          icon: Icons.fact_check_outlined,
          child: analysis.ruleAnalysis.indicators.isEmpty
              ? const Text('No specific threat indicators were detected.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final indicator in analysis.ruleAnalysis.indicators)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.flag_outlined,
                              size: 16,
                              color: AppTheme.suspiciousColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    indicator.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    indicator.description,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        if (_analysedText.isNotEmpty) ...[
          const SizedBox(height: 14),
          SectionCard(
            title: 'Analysed text',
            icon: Icons.notes_outlined,
            child: Text(
              _analysedText,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sourceNote(BuildContext context, HybridThreatAnalysis analysis) {
    final (label, icon) = switch (analysis.source) {
      VerdictSource.consensus => ('Rules and model agree', Icons.handshake_outlined),
      VerdictSource.machineLearning => ('Decided by the model', Icons.memory_outlined),
      VerdictSource.ruleEngine => ('Decided by rules', Icons.rule_outlined),
      VerdictSource.modelOverride => ('Model overruled weak rules', Icons.tune_outlined),
      VerdictSource.externalReport => (
        'Reported by a trusted source',
        Icons.report_outlined,
      ),
      VerdictSource.none => ('No signal found', Icons.check_circle_outline),
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 15),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
