import 'package:flutter/material.dart';

import '../../../../core/models/breach_record.dart';
import '../../../../core/services/breach_check_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/threat_widgets.dart';

/// Checks an e-mail address or phone number against the bundled breach
/// catalogue, entirely on-device.
class BreachExposureScreen extends StatefulWidget {
  const BreachExposureScreen({
    super.key,
    this.service = const BreachCheckService(),
  });

  final BreachCheckService service;

  @override
  State<BreachExposureScreen> createState() => _BreachExposureScreenState();
}

class _BreachExposureScreenState extends State<BreachExposureScreen> {
  final TextEditingController _controller = TextEditingController();

  BreachExposureResult? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _check() {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter an e-mail address or phone number.'),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _result = widget.service.check(input));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Breach check')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _privacyNotice(context),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            onSubmitted: (_) => _check(),
            decoration: const InputDecoration(
              labelText: 'E-mail address or phone number',
              hintText: 'you@example.com',
              prefixIcon: Icon(Icons.alternate_email),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _check,
            icon: const Icon(Icons.search),
            label: const Text('Check for exposure'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 22),
            _resultCard(context, _result!),
            const SizedBox(height: 14),
            _remediationCard(context, _result!),
            if (_result!.isExposed) ...[
              const SizedBox(height: 14),
              _breachListCard(context, _result!),
            ],
          ],
          const SizedBox(height: 20),
          _catalogCard(context),
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
                    'Checked offline by default',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This check runs against a bundled list with no network '
                    'request. If you enable online lookup, ThreatGuard uses a '
                    'k-anonymity range query: only the first five characters '
                    'of a hash are sent, and the match happens here. Your '
                    'address itself is never transmitted.',
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

  Widget _resultCard(BuildContext context, BreachExposureResult result) {
    final exposed = result.isExposed;
    final color = exposed ? AppTheme.highRiskColor : AppTheme.safeColor;

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
              child: Icon(
                exposed
                    ? Icons.gpp_maybe_rounded
                    : Icons.verified_user_outlined,
                size: 32,
                color: color,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              exposed
                  ? 'Found in ${result.matches.length} '
                        'breach${result.matches.length == 1 ? '' : 'es'}'
                  : 'No exposure found',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              result.maskedIdentifier,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (exposed) ...[
              const SizedBox(height: 14),
              MetricBar(
                label: 'Exposure severity',
                value: result.severity / 100,
                color: result.severity >= 60
                    ? AppTheme.highRiskColor
                    : AppTheme.suspiciousColor,
                trailing: '${result.severity}/100',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _remediationCard(BuildContext context, BreachExposureResult result) {
    final steps = BreachCheckService.remediationFor(result);

    return SectionCard(
      title: result.isExposed ? 'What to do, in order' : 'Staying safe',
      icon: Icons.shield_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: const TextStyle(fontSize: 13, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _breachListCard(BuildContext context, BreachExposureResult result) {
    return SectionCard(
      title: 'Which breaches',
      icon: Icons.history_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final breach in result.matches)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          breach.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.suspiciousColor.withValues(
                            alpha: 0.14,
                          ),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          breach.year,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.suspiciousColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    breach.description,
                    style: const TextStyle(fontSize: 12.5, height: 1.45),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final kind in breach.exposed)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: kind == BreachDataKind.password
                                  ? AppTheme.highRiskColor.withValues(
                                      alpha: 0.5,
                                    )
                                  : Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Text(
                            _dataKindLabel(kind),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: kind == BreachDataKind.password
                                  ? AppTheme.highRiskColor
                                  : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _catalogCard(BuildContext context) {
    const catalog = BreachCatalog();

    return SectionCard(
      title: 'About this list',
      icon: Icons.info_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ThreatGuard ships with a sample of well-known breaches '
            '(${catalog.all.length} entries). It is a starting point, not '
            'complete coverage — a clean result here does not prove your '
            'details have never leaked.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final breach in catalog.all)
                Chip(
                  label: Text(
                    '${breach.name} (${breach.year})',
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _dataKindLabel(BreachDataKind kind) => switch (kind) {
    BreachDataKind.email => 'E-mail',
    BreachDataKind.password => 'Password',
    BreachDataKind.phone => 'Phone',
    BreachDataKind.name => 'Name',
    BreachDataKind.address => 'Address',
    BreachDataKind.paymentCard => 'Payment card',
    BreachDataKind.dateOfBirth => 'Date of birth',
    BreachDataKind.nationalId => 'National ID',
  };
}
