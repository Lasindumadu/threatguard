import 'package:flutter/material.dart';

import '../../../../core/services/breach_check_service.dart';
import '../../../../core/services/link_safety_service.dart';
import '../../../../core/theme/app_theme.dart';
import 'breach_exposure_screen.dart';
import 'link_scanner_screen.dart';
import 'password_audit_screen.dart';
import 'permission_surface_screen.dart';
import 'security_posture_screen.dart';
import 'threat_feed_screen.dart';

/// The index of security tools.
///
/// This screen is what turns "an SMS classifier" into "a security app": the
/// same analysis engines, reachable for any link, password or number the user
/// is worried about — not only for messages ThreatGuard happened to read.
class ToolsScreen extends StatelessWidget {
  final LinkSafetyService linkSafetyService;
  final BreachCheckService breachCheckService;
  final VoidCallback onOpenTips;

  const ToolsScreen({
    super.key,
    required this.linkSafetyService,
    required this.breachCheckService,
    required this.onOpenTips,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Extra bottom padding so the final tile is not clipped behind the
      // navigation bar on short screens.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text(
          'Everything here runs on your device. Use these tools on anything — '
          'not just the messages ThreatGuard has read.',
          style: TextStyle(
            height: 1.45,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        _toolTile(
          context,
          icon: Icons.travel_explore_outlined,
          title: 'Link scanner',
          subtitle:
              'Paste any link to see its real destination domain, spot brand '
              'impersonation, and check for shorteners, raw IP hosts and '
              'hidden characters.',
          badge: 'Offline',
          onTap: () => _push(
            context,
            LinkScannerScreen(safetyService: linkSafetyService),
          ),
        ),
        _toolTile(
          context,
          icon: Icons.password_outlined,
          title: 'Password audit',
          subtitle:
              'Measure a password\'s real entropy, find the patterns that make '
              'it weak, and generate a strong passphrase.',
          badge: 'Never leaves device',
          onTap: () => _push(context, const PasswordAuditScreen()),
        ),
        _toolTile(
          context,
          icon: Icons.alternate_email,
          title: 'Breach check',
          subtitle:
              'Check whether an e-mail address or phone number appears in known '
              'data breaches, and get a prioritised list of what to do.',
          badge: 'On-device',
          onTap: () =>
              _push(context, BreachExposureScreen(service: breachCheckService)),
        ),
        _toolTile(
          context,
          icon: Icons.phonelink_lock_outlined,
          title: 'Device posture',
          subtitle:
              'A scored checklist of your device security settings, with the '
              'fix for anything that fails.',
          onTap: () => _push(context, const SecurityPostureScreen()),
        ),
        _toolTile(
          context,
          icon: Icons.campaign_outlined,
          title: 'Threat awareness',
          subtitle:
              'How the common scams in this region actually work — the wording '
              'they use, what they want, and how to shut them down.',
          onTap: () => _push(context, const ThreatFeedScreen()),
        ),
        _toolTile(
          context,
          icon: Icons.tips_and_updates_outlined,
          title: 'Your security advice',
          subtitle:
              'Recommendations built from what ThreatGuard has actually seen '
              'in your messages, not generic tips.',
          onTap: onOpenTips,
        ),
        _toolTile(
          context,
          icon: Icons.privacy_tip_outlined,
          title: 'Permissions and data',
          subtitle:
              'Exactly which permissions ThreatGuard holds, what each one is '
              'used for, and what leaves the device.',
          isLast: true,
          onTap: () => _push(context, const PermissionSurfaceScreen()),
        ),
      ],
    );
  }

  Widget _toolTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badge,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(
                    icon,
                    size: 21,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.safeColor.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.safeColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}
