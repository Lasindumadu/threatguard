import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/threat_widgets.dart';

/// A permission entry and its justification.
class PermissionEntry {
  final String permission;
  final String purpose;
  final String justification;
  final bool isRestricted;
  final bool isRequired;

  const PermissionEntry({
    required this.permission,
    required this.purpose,
    required this.justification,
    this.isRestricted = false,
    this.isRequired = true,
  });
}

/// What ThreatGuard can access, why, and what leaves the device.
///
/// This screen exists for two audiences at once. For a user it is a plain
/// statement of what the app can see. For a Play Store reviewer it is the
/// permission declaration in context — the `READ_SMS` justification is the
/// single biggest obstacle to shipping this app, so it is written out here
/// rather than left implicit in a manifest.
class PermissionSurfaceScreen extends StatelessWidget {
  const PermissionSurfaceScreen({super.key});

  static const List<PermissionEntry> permissions = [
    PermissionEntry(
      permission: 'READ_SMS',
      purpose: 'Read text messages so they can be checked for scams.',
      justification:
          'ThreatGuard\'s core function is detecting phishing and scam text '
          'messages on the user\'s own device. This is the primary purpose of '
          'the app, disclosed in the store listing and in the in-app onboarding '
          'before the permission is requested. Analysis happens entirely '
          'on-device; no message content is transmitted, stored remotely, or '
          'shared with any third party. The app is not a default SMS handler '
          'and does not send, modify or delete messages.',
      isRestricted: true,
    ),
    PermissionEntry(
      permission: 'INTERNET',
      purpose: 'Optional link-reputation and breach lookups.',
      justification:
          'Used only when the user explicitly enables an online lookup. The '
          'app functions fully offline; no request is made by default. Breach '
          'checks use a k-anonymity range query, transmitting only a '
          'five-character hash prefix.',
      isRequired: false,
    ),
    PermissionEntry(
      permission: 'Clipboard (user-initiated)',
      purpose: 'Pasting a message or link to check it.',
      justification:
          'The clipboard is read only when the user taps Paste. Optional '
          'clipboard monitoring is off by default and never enabled silently.',
      isRequired: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions and data')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _privacyCard(context),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Permissions ThreatGuard holds',
            icon: Icons.privacy_tip_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in permissions)
                  _permissionTile(context, entry),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'What leaves this device',
            icon: Icons.cloud_off_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dataRow(
                  context,
                  'Message text',
                  'Never',
                  Icons.close,
                  AppTheme.safeColor,
                ),
                _dataRow(
                  context,
                  'Sender numbers',
                  'Never',
                  Icons.close,
                  AppTheme.safeColor,
                ),
                _dataRow(
                  context,
                  'Links you scan',
                  'Never (off by default)',
                  Icons.close,
                  AppTheme.safeColor,
                ),
                _dataRow(
                  context,
                  'Breach-check string',
                  '5-char hash prefix only',
                  Icons.check,
                  AppTheme.suspiciousColor,
                ),
                _dataRow(
                  context,
                  'Passwords you test',
                  'Never — not even hashed',
                  Icons.close,
                  AppTheme.safeColor,
                ),
                const SizedBox(height: 10),
                Text(
                  'ThreatGuard contains no analytics SDK, no advertising SDK '
                  'and no crash-reporting SDK. There is no account system.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _limitationsCard(context),
        ],
      ),
    );
  }

  Widget _privacyCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.safeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                color: AppTheme.safeColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Local by design',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Detection runs on this device. The rules engine, the '
                    'classifier, the link analysis and the password audit all '
                    'compute locally, so the app works in airplane mode and has '
                    'nothing to leak.',
                    style: TextStyle(
                      height: 1.45,
                      fontSize: 13,
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

  Widget _permissionTile(BuildContext context, PermissionEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.permission,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (entry.isRestricted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.suspiciousColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Restricted',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.suspiciousColor,
                    ),
                  ),
                ),
              if (!entry.isRequired) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.safeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Optional',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.safeColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            entry.purpose,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            entry.justification,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _limitationsCard(BuildContext context) {
    return SectionCard(
      title: 'Honest limitations',
      icon: Icons.info_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _limitation(
            context,
            'WhatsApp, Messenger and Instagram messages cannot be read '
                'automatically.',
            'Those apps encrypt message databases and expose no read API. '
                'ThreatGuard receives them through the Android share sheet instead, '
                'so you stay in control of what gets checked.',
          ),
          _limitation(
            context,
            'Breach coverage is a sample, not complete.',
            'The bundled breach catalogue is a starting point. A clean result '
                'means "not in this list", not "never leaked".',
          ),
          _limitation(
            context,
            'Some device checks cannot be verified.',
            'Android does not expose the OS patch level or per-app unknown-'
                'sources settings to a normal app. Those checks are reported as '
                'unknown rather than guessed.',
          ),
          _limitation(
            context,
            'Detection is strong but not perfect.',
            'Published held-out metrics are in Settings → Model health. Treat '
                'a low-risk verdict as "nothing found", not as a guarantee.',
          ),
        ],
      ),
    );
  }

  Widget _limitation(BuildContext context, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 3),
          Text(
            body,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
