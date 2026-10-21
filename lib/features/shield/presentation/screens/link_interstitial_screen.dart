import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/link_safety_service.dart';
import '../../../../core/theme/app_theme.dart';

/// The pre-flight warning shown before a risky link opens.
///
/// This is the app's most consequential screen: it stands between a user and a
/// phishing page. Three rules shape it:
///
///  1. **The real destination is the hero.** The whole trick is that the
///     visible text says one thing and the address bar says another, so the
///     registrable domain is the largest element on the screen.
///  2. **Proceeding is possible but deliberate.** Blocking outright trains
///     users to route around the app; a clear override with a confirm step
///     keeps them inside it.
///  3. **Non-web schemes cannot be opened at all.** `intent:`, `tg:` and
///     `javascript:` can launch apps or run code, so there is no override.
class LinkInterstitialScreen extends StatefulWidget {
  final LinkSafety safety;
  final VoidCallback onProceed;
  final VoidCallback onDismiss;

  const LinkInterstitialScreen({
    super.key,
    required this.safety,
    required this.onProceed,
    required this.onDismiss,
  });

  @override
  State<LinkInterstitialScreen> createState() => _LinkInterstitialScreenState();
}

class _LinkInterstitialScreenState extends State<LinkInterstitialScreen> {
  bool _acknowledged = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final safety = widget.safety;
    final dangerous = safety.isDangerous;
    final color = dangerous ? AppTheme.highRiskColor : AppTheme.suspiciousColor;

    final openable = safety.isOpenableScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                children: [
                  _shield(context, color, dangerous),
                  const SizedBox(height: 22),
                  _destination(context),
                  const SizedBox(height: 18),
                  if (safety.reasons.isNotEmpty) _reasons(context),
                  const SizedBox(height: 18),
                  _advice(context),
                  const SizedBox(height: 18),
                  if (openable)
                    _overrideControl(context)
                  else
                    _blockedNotice(context),
                ],
              ),
            ),
            _actions(context, openable),
          ],
        ),
      ),
    );
  }

  Widget _shield(BuildContext context, Color color, bool dangerous) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          ),
          child: Icon(
            dangerous ? Icons.gpp_bad_rounded : Icons.warning_amber_rounded,
            size: 46,
            color: color,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          widget.safety.headline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: color,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'ThreatGuard stopped this link before it opened.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// The single most important element: where the link actually goes.
  Widget _destination(BuildContext context) {
    final forensics = widget.safety.forensics;
    final registrable = forensics.registrableDomain ?? forensics.host;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.highRiskColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.highRiskColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This link actually goes to',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            registrable,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          if (forensics.subdomain != null &&
              forensics.subdomain!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'hidden behind: ${forensics.subdomain}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Risk score ${widget.safety.score}/100',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.highRiskColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reasons(BuildContext context) {
    final reasons = widget.safety.reasons.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Why it was blocked',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        for (final reason in reasons)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: AppTheme.highRiskColor,
                  ),
                ),
                const SizedBox(width: 10),
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
    );
  }

  Widget _advice(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.safeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.safeColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 18,
            color: AppTheme.safeColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What to do instead',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.safety.recommendation,
                  style: const TextStyle(fontSize: 12.5, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The deliberate override: a checkbox the user must actively tick.
  Widget _overrideControl(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _acknowledged,
            onChanged: (value) =>
                setState(() => _acknowledged = value ?? false),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'I understand this link may be a phishing attempt and I '
                'accept the risk.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Non-web schemes get no override at all.
  Widget _blockedNotice(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.highRiskColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.block, size: 18, color: AppTheme.highRiskColor),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'This is not a web address. ThreatGuard will not open '
              '"${widget.safety.forensics.scheme}" links, because schemes like '
              'intent:, tg: and javascript: can launch other apps or run code.',
              style: const TextStyle(fontSize: 12.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, bool openable) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          // The safe action is primary and full width: the easiest thing to do
          // should be the right thing to do.
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.onDismiss,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.safeColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 52),
              ),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text(
                'Go back to safety',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (openable) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _acknowledged
                  ? () {
                      HapticFeedback.vibrate().catchError((_) {});
                      widget.onProceed();
                    }
                  : null,
              child: Text(
                _acknowledged
                    ? 'Open anyway (not recommended)'
                    : 'Tick the box above to open anyway',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
