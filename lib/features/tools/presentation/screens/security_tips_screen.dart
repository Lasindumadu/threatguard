import 'package:flutter/material.dart';

import '../../../../core/services/security_tips_engine.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/threat_widgets.dart';

/// Personalised security advice derived from observed data.
class SecurityTipsScreen extends StatelessWidget {
  final List<SecurityTip> tips;

  const SecurityTipsScreen({super.key, this.tips = const []});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your security advice')),
      body: tips.isEmpty
          ? const EmptyState(
              icon: Icons.tips_and_updates_outlined,
              title: 'No advice yet',
              message:
                  'Scan or share a few messages and ThreatGuard will build '
                  'recommendations from what it actually sees in your inbox.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  'Built from your messages',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Each item below is justified by something ThreatGuard '
                  'observed on this device. Generic advice gets ignored; your '
                  'own numbers are harder to dismiss.',
                  style: TextStyle(
                    height: 1.45,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                for (final tip in tips) _tipCard(context, tip),
              ],
            ),
    );
  }

  Widget _tipCard(BuildContext context, SecurityTip tip) {
    final (icon, color) = switch (tip.category) {
      TipCategory.messages => (Icons.sms_outlined, AppTheme.suspiciousColor),
      TipCategory.links => (Icons.link, AppTheme.highRiskColor),
      TipCategory.accounts => (Icons.key_outlined, AppTheme.safeColor),
      TipCategory.device => (Icons.phonelink_lock_outlined, AppTheme.safeColor),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        title: _categoryLabel(tip.category),
        icon: icon,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            'P${tip.priority}',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.visibility_outlined,
                    size: 14,
                    color: AppTheme.suspiciousColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tip.observation,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppTheme.safeColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tip.action,
                    style: const TextStyle(fontSize: 13, height: 1.45),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _categoryLabel(TipCategory category) => switch (category) {
    TipCategory.messages => 'Messages',
    TipCategory.links => 'Links',
    TipCategory.accounts => 'Accounts',
    TipCategory.device => 'Device',
  };
}
