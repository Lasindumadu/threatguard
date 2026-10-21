import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/impersonation_detector.dart';
import '../../../../core/services/link_safety_service.dart';
import '../../../../core/services/url_forensics_analyzer.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/threat_widgets.dart';

/// Deep URL inspection: paste any link and see exactly how it decomposes and
/// what is wrong with it.
class LinkScannerScreen extends StatefulWidget {
  const LinkScannerScreen({
    super.key,
    required this.safetyService,
    this.initialUrl,
  });

  final LinkSafetyService safetyService;

  /// Pre-fills and immediately scans a link, e.g. one raised by the clipboard
  /// watcher.
  final String? initialUrl;

  @override
  State<LinkScannerScreen> createState() => _LinkScannerScreenState();
}

class _LinkScannerScreenState extends State<LinkScannerScreen> {
  final TextEditingController _controller = TextEditingController();

  LinkSafety? _result;
  bool _isChecking = false;

  static const _samples = <String, String>{
    'Genuine bank': 'https://www.hnb.lk/',
    'Lookalike': 'https://hnb-secure-login.top/verify',
    'Hidden destination': 'https://www.hnb.lk@evil-collect.top/login',
    'IP address host': 'http://203.0.113.9/bank/login',
    'Shortened': 'https://bit.ly/3xYzAbC',
    'Long subdomain chain': 'https://login.secure.bank.verify.evil.top/',
  };

  @override
  void initState() {
    super.initState();

    final initial = widget.initialUrl?.trim();
    if (initial != null && initial.isNotEmpty) {
      _controller.text = initial;
      _result = widget.safetyService.analyzeOffline(initial);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scan() {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste or type a link first.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isChecking = true;
      _result = null;
    });

    // Offline analysis is synchronous and cannot fail on valid input, but a
    // malformed URL is still user input: it must produce a result, not a crash.
    LinkSafety result;
    try {
      result = widget.safetyService.analyzeOffline(input);
    } catch (_) {
      result = widget.safetyService.analyzeOffline('');
    }

    if (!mounted) return;

    setState(() {
      _isChecking = false;
      _result = result;
    });
  }

  Future<void> _paste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) return;
      if (!mounted) return;
      setState(() => _controller.text = text);
    } catch (_) {
      // Clipboard unavailable (web, denied): the field is still editable.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Link scanner')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Inspect any link',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'ThreatGuard breaks a link into its real parts, checks it for '
            'brand impersonation, and explains anything dangerous. This runs '
            'offline.',
            style: TextStyle(
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 4,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Link',
              hintText: 'https://example.com/path',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isChecking ? null : _scan,
                  icon: const Icon(Icons.travel_explore_outlined),
                  label: const Text('Scan link'),
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
          const SizedBox(height: 18),
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
                  onPressed: () {
                    setState(() {
                      _controller.text = sample.value;
                      _result = null;
                    });
                    _scan();
                  },
                ),
            ],
          ),
          if (_result != null) ...[
            const SizedBox(height: 24),
            _resultView(context, _result!),
          ],
        ],
      ),
    );
  }

  Widget _resultView(BuildContext context, LinkSafety safety) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _verdictCard(context, safety),
        const SizedBox(height: 14),
        _decompositionCard(context, safety.forensics),
        const SizedBox(height: 14),
        if (safety.forensics.impersonation != null &&
            safety.forensics.impersonation!.verdict !=
                ImpersonationVerdict.noMatch) ...[
          _impersonationCard(context, safety.forensics.impersonation!),
          const SizedBox(height: 14),
        ],
        if (safety.reasons.isNotEmpty) ...[
          SectionCard(
            title: 'What was found (${safety.reasons.length})',
            icon: Icons.fact_check_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final reason in safety.reasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            size: 15,
                            color: AppTheme.suspiciousColor,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            reason,
                            style: const TextStyle(fontSize: 13, height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        SectionCard(
          title: 'What you should do',
          icon: Icons.shield_outlined,
          child: Text(
            safety.recommendation,
            style: const TextStyle(height: 1.45),
          ),
        ),
      ],
    );
  }

  Widget _verdictCard(BuildContext context, LinkSafety safety) {
    final color = switch (safety.verdict) {
      LinkSafetyGrade.looksSafe => AppTheme.safeColor,
      LinkSafetyGrade.suspicious => AppTheme.suspiciousColor,
      LinkSafetyGrade.dangerous => AppTheme.highRiskColor,
    };

    final icon = switch (safety.verdict) {
      LinkSafetyGrade.looksSafe => Icons.verified_user_outlined,
      LinkSafetyGrade.suspicious => Icons.warning_amber_rounded,
      LinkSafetyGrade.dangerous => Icons.gpp_bad_rounded,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: color),
            ),
            const SizedBox(height: 14),
            Text(
              safety.headline,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Risk score ${safety.score}/100',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (!safety.isOpenableScheme) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.highRiskColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Text(
                  'This is not a web link (http/https). ThreatGuard will not '
                  'open other link types, because schemes like intent:, tg: '
                  'and javascript: can launch apps or run code.',
                  style: TextStyle(fontSize: 12.5, height: 1.45),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The host breakdown, which is the feature most people find genuinely
  /// useful: seeing `evil.top` highlighted inside a long, official-looking
  /// address.
  Widget _decompositionCard(BuildContext context, UrlForensics forensics) {
    if (forensics.host.isEmpty) {
      return SectionCard(
        title: 'Link breakdown',
        icon: Icons.account_tree_outlined,
        child: const Text('This text was not recognised as a web address.'),
      );
    }

    return SectionCard(
      title: 'Link breakdown',
      icon: Icons.account_tree_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hostBreakdown(context, forensics),
          const Divider(height: 22),
          _row(
            context,
            'Scheme',
            forensics.isHttps ? 'https' : forensics.scheme,
          ),
          if (forensics.publicSuffix != null)
            _row(context, 'Top-level domain', '.${forensics.publicSuffix}'),
          if (forensics.port != null)
            _row(context, 'Port', '${forensics.port}'),
          if (forensics.path.isNotEmpty) _row(context, 'Path', forensics.path),
          if (forensics.query != null) _row(context, 'Query', forensics.query!),
          _row(context, 'Subdomains', '${forensics.subdomainCount}'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The site you would actually reach',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  forensics.displayAddress,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hostBreakdown(BuildContext context, UrlForensics forensics) {
    final registrable = forensics.registrableDomain ?? forensics.host;
    final impersonation = forensics.impersonation;
    final registrableIsBad = impersonation?.isConcerning ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Host name, part by part',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 2,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (forensics.subdomain != null && forensics.subdomain!.isNotEmpty)
              _hostPart(context, '${forensics.subdomain}.', muted: true),
            _hostPart(context, registrable, highlighted: registrableIsBad),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          registrableIsBad
              ? 'The highlighted part is the domain you would really connect '
                    'to. Everything before it is decoration, and anyone can put '
                    'a bank name there.'
              : 'The highlighted part is the domain you would really connect '
                    'to. Anything written before it does not change where the '
                    'link goes.',
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _hostPart(
    BuildContext context,
    String text, {
    bool muted = false,
    bool highlighted = false,
  }) {
    final color = highlighted
        ? AppTheme.highRiskColor
        : muted
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: highlighted
          ? BoxDecoration(
              color: AppTheme.highRiskColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(5),
            )
          : null,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _impersonationCard(BuildContext context, ImpersonationCheck check) {
    final concerning = check.isConcerning;

    return SectionCard(
      title: 'Brand check',
      icon: concerning ? Icons.gpp_bad_outlined : Icons.verified_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            check.summary,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: concerning ? AppTheme.highRiskColor : AppTheme.safeColor,
            ),
          ),
          if (check.reasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final reason in check.reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  reason,
                  style: const TextStyle(fontSize: 12.5, height: 1.45),
                ),
              ),
          ],
          if (check.officialDomain != null && concerning) ...[
            const SizedBox(height: 8),
            Text(
              'The official domain is ${check.officialDomain}.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small helper used by the message detail screen to show a link verdict inline.
class LinkVerdictChip extends StatelessWidget {
  final LinkSafety safety;
  final VoidCallback? onTap;

  const LinkVerdictChip({super.key, required this.safety, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = switch (safety.verdict) {
      LinkSafetyGrade.looksSafe => AppTheme.safeColor,
      LinkSafetyGrade.suspicious => AppTheme.suspiciousColor,
      LinkSafetyGrade.dangerous => AppTheme.highRiskColor,
    };

    final label = switch (safety.verdict) {
      LinkSafetyGrade.looksSafe => 'No issues found',
      LinkSafetyGrade.suspicious => 'Suspicious',
      LinkSafetyGrade.dangerous => 'Dangerous',
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              safety.isSafe
                  ? Icons.verified_outlined
                  : Icons.warning_amber_rounded,
              size: 13,
              color: color,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
