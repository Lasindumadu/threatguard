import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/password_strength_analyzer.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/threat_widgets.dart';

/// Password strength audit.
///
/// Privacy rules enforced here, not just documented:
///  * The password lives only in a `TextEditingController` and is disposed on
///    exit. It is never written to storage, never logged, and never sent
///    anywhere — this screen makes no network call at all.
///  * `autocorrect`, `enableSuggestions` and the keyboard's own learning are
///    disabled, so the platform does not retain it either.
class PasswordAuditScreen extends StatefulWidget {
  const PasswordAuditScreen({super.key});

  @override
  State<PasswordAuditScreen> createState() => _PasswordAuditScreenState();
}

class _PasswordAuditScreenState extends State<PasswordAuditScreen> {
  final TextEditingController _controller = TextEditingController();
  final PassphraseGenerator _generator = const PassphraseGenerator();
  final PasswordStrengthAnalyzer _analyzer = const PasswordStrengthAnalyzer();

  PasswordAnalysis? _analysis;
  GeneratedPassphrase? _generated;
  bool _obscured = true;
  bool _showGenerator = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    // Clearing before disposal means the characters are dropped from the
    // controller's buffer immediately rather than surviving until GC.
    _controller.clear();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {
      _analysis = _controller.text.isEmpty
          ? null
          : _analyzer.analyze(_controller.text);
    });
  }

  void _generate() {
    final generated = _generator.generate();

    setState(() {
      _generated = generated;
      _controller.text = generated.value;
    });
  }

  Future<void> _copyGenerated() async {
    final generated = _generated;
    if (generated == null) return;

    await Clipboard.setData(ClipboardData(text: generated.value));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Passphrase copied. Save it in a password manager, then clear your '
          'clipboard.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Password audit')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _privacyNotice(context),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: _obscured,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Check a password',
              hintText: 'Type or paste a password to test it',
              prefixIcon: const Icon(Icons.password_outlined),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscured = !_obscured),
                icon: Icon(
                  _obscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                tooltip: _obscured ? 'Show' : 'Hide',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _controller.clear();
                    setState(() {
                      _analysis = null;
                      _generated = null;
                    });
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      setState(() => _showGenerator = !_showGenerator),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Generate'),
                ),
              ),
            ],
          ),
          if (_showGenerator) ...[
            const SizedBox(height: 16),
            _generatorCard(context),
          ],
          if (_analysis != null) ...[
            const SizedBox(height: 20),
            _strengthCard(context, _analysis!),
            const SizedBox(height: 14),
            _metricsCard(context, _analysis!),
            if (_analysis!.issues.isNotEmpty) ...[
              const SizedBox(height: 14),
              _issuesCard(context, _analysis!),
            ],
            if (_analysis!.suggestions.isNotEmpty) ...[
              const SizedBox(height: 14),
              SectionCard(
                title: 'How to improve it',
                icon: Icons.tips_and_updates_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final suggestion in _analysis!.suggestions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 3),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: AppTheme.safeColor,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                suggestion,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _privacyNotice(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppTheme.safeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 18,
                color: AppTheme.safeColor,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This password never leaves your phone',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'The check is pure arithmetic on this device. Nothing is '
                    'saved, transmitted or logged, and it is cleared as soon as '
                    'you leave this screen.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _strengthCard(BuildContext context, PasswordAnalysis analysis) {
    final color = switch (analysis.strength) {
      PasswordStrength.critical => AppTheme.highRiskColor,
      PasswordStrength.weak => AppTheme.highRiskColor,
      PasswordStrength.fair => AppTheme.suspiciousColor,
      PasswordStrength.strong => AppTheme.safeColor,
      PasswordStrength.excellent => AppTheme.safeColor,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      analysis.strengthLabel,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${analysis.entropyBits.toStringAsFixed(0)} bits of entropy',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${analysis.score}',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: analysis.score / 100),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 9,
                  backgroundColor: Theme.of(context).dividerColor,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.speed_outlined, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A dedicated cracking rig would need about '
                    '${analysis.crackTimeDescription} to guess it.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricsCard(BuildContext context, PasswordAnalysis analysis) {
    return SectionCard(
      title: 'Measured properties',
      icon: Icons.straighten_outlined,
      child: Column(
        children: [
          MetricBar(
            label: 'Length (${analysis.length} characters)',
            value: (analysis.length / 24).clamp(0.0, 1.0),
            color: analysis.length >= 14
                ? AppTheme.safeColor
                : analysis.length >= 12
                ? AppTheme.suspiciousColor
                : AppTheme.highRiskColor,
            trailing: '${analysis.length}',
          ),
          MetricBar(
            label: 'Character types used',
            value: analysis.characterClasses / 4,
            color: analysis.characterClasses >= 3
                ? AppTheme.safeColor
                : AppTheme.suspiciousColor,
            trailing: '${analysis.characterClasses}/4',
          ),
        ],
      ),
    );
  }

  Widget _issuesCard(BuildContext context, PasswordAnalysis analysis) {
    return SectionCard(
      title: 'Problems found (${analysis.issues.length})',
      icon: Icons.report_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final issue in analysis.issues)
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: AppTheme.highRiskColor,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          issue.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          issue.detail,
                          style: const TextStyle(fontSize: 12.5, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _generatorCard(BuildContext context) {
    return SectionCard(
      title: 'Generate a strong passphrase',
      icon: Icons.auto_awesome_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Random words are easier to remember than random characters and '
            'just as strong. Uses a cryptographically secure random source.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _generate,
            icon: const Icon(Icons.casino_outlined),
            label: const Text('Generate passphrase'),
          ),
          if (_generated != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: SelectableText(
                _generated!.value,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 15,
                  color: AppTheme.safeColor,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '${_generated!.entropyBits.toStringAsFixed(0)} bits — '
                    'generated from a known keyspace, so this is exact, not an '
                    'estimate.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _copyGenerated,
              icon: const Icon(Icons.copy_outlined, size: 16),
              label: const Text('Copy to clipboard'),
            ),
          ],
        ],
      ),
    );
  }
}
