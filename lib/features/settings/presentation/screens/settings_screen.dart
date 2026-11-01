import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/local_store.dart';
import '../../../../core/services/threat_engine.dart';
import '../../../../core/theme/app_skin.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/threat_widgets.dart';

/// Settings, privacy controls, and the feedback export.
class SettingsScreen extends StatefulWidget {
  final LocalStore? store;
  final ThreatEngine engine;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final AppSkin skin;
  final ValueChanged<AppSkin> onSkinChanged;
  final VoidCallback onOpenInsights;
  final VoidCallback onOpenShield;

  /// Called when clipboard watch is toggled.
  final ValueChanged<bool>? onClipboardWatchChanged;

  /// Called when online lookup is toggled.
  final ValueChanged<bool>? onOnlineLookupChanged;

  /// Called when reduce-motion toggle is changed.
  final ValueChanged<bool>? onReduceMotionChanged;

  const SettingsScreen({
    super.key,
    required this.store,
    required this.engine,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.skin,
    required this.onSkinChanged,
    required this.onOpenInsights,
    required this.onOpenShield,
    this.onClipboardWatchChanged,
    this.onOnlineLookupChanged,
    this.onReduceMotionChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final store = widget.store;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _privacyCard(context),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Appearance',
          icon: Icons.palette_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined, size: 16),
                    label: Text('Auto'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined, size: 16),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined, size: 16),
                    label: Text('Dark'),
                  ),
                ],
                selected: {widget.themeMode},
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) {
                    widget.onThemeModeChanged(selection.first);
                  }
                },
              ),
               const SizedBox(height: 8),
               Text(
                 'Both themes use the same risk colours, so a red flag means the '
                 'same thing whichever you choose.',
                 style: TextStyle(
                   fontSize: 12.5,
                   height: 1.4,
                   color: Theme.of(context).colorScheme.onSurfaceVariant,
                 ),
               ),
               const SizedBox(height: 16),
               const Text(
                 'Neon Theme Preset',
                 style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
               ),
               const SizedBox(height: 8),
               Wrap(
                 spacing: 8,
                 runSpacing: 8,
                 children: AppSkin.values.map((skin) {
                   final isSelected = widget.skin == skin;
                   return ChoiceChip(
                     label: Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Container(
                           width: 12,
                           height: 12,
                           decoration: BoxDecoration(
                             color: skin.primary,
                             shape: BoxShape.circle,
                             boxShadow: [
                               BoxShadow(
                                 color: skin.glow.withValues(alpha: 0.6),
                                 blurRadius: 6,
                               ),
                             ],
                           ),
                         ),
                         const SizedBox(width: 6),
                         Text(skin.name),
                       ],
                     ),
                     selected: isSelected,
                     onSelected: (selected) {
                       if (selected) {
                         widget.onSkinChanged(skin);
                       }
                     },
                   );
                 }).toList(),
               ),
               const SizedBox(height: 8),
              // Reduce motion toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reduce animations'),
                value: widget.onReduceMotionChanged != null &&
                    (store?.reduceMotionEnabled ?? false),
                onChanged: widget.onReduceMotionChanged != null
                    ? (value) {
                        widget.onReduceMotionChanged!.call(value);
                        setState(() {});
                      }
                    : null,
                subtitle: const Text(
                  'Reduce movement and animation for accessibility',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'When enabled, the app will use instant transitions instead of '
                'animated ones.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Detection',
          icon: Icons.tune_outlined,
          child: Column(
            children: [
              // Detection sensitivity lives on the Shield tab, where the
              // thresholds it changes are shown next to it. Duplicating the
              // control here let the two settings disagree.
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Detection sensitivity'),
                subtitle: Text(
                  store == null
                      ? 'Configured on the Shield tab.'
                      : 'Currently ${store.protectionMode.label.toLowerCase()}. '
                            'Change it on the Shield tab.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: widget.onOpenShield,
              ),
              const Divider(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: store?.onlineLookupEnabled ?? false,
                onChanged: store == null
                    ? null
                    : (value) async {
                        // Apply live, then persist. Before Phase 1 this only
                        // wrote the store, and nothing read the flag.
                        widget.onOnlineLookupChanged?.call(value);
                        await store.setOnlineLookupEnabled(value);
                        setState(() {});
                      },
                title: const Text('Online link reputation lookup'),
                subtitle: const Text(
                  'Off by default. When enabled, link addresses may be sent to '
                  'a reputation service — never the message text.',
                ),
              ),
              const Divider(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: store?.clipboardWatchEnabled ?? false,
                onChanged: store == null
                    ? null
                    : (value) async {
                        // Ownership: Settings persists, the shell applies.
                        // (This used to persist twice and apply once.)
                        widget.onClipboardWatchChanged?.call(value);
                        await store.setClipboardWatchEnabled(value);
                        setState(() {});
                      },
                title: const Text('Clipboard link watch'),
                subtitle: const Text(
                  'Off by default. When enabled, ThreatGuard checks links you '
                  'copy for phishing and warns you before you tap them.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _modelCard(context),
        const SizedBox(height: 14),
        _feedbackCard(context, store),
        const SizedBox(height: 14),
        SectionCard(
          title: 'About',
          icon: Icons.info_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ThreatGuard 1.0',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'On-device SMS and message threat classification. No account, '
                'no analytics, no cloud.',
                style: TextStyle(
                  height: 1.45,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Version 1.0.0+1',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Built with Flutter Framework',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No account, no analytics, no cloud.',
                style: TextStyle(
                  height: 1.45,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
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
                    'Your messages stay on your device',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'All analysis happens locally. ThreatGuard does not upload '
                    'message content, does not use analytics SDKs, and does '
                    'not require an account.',
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

  Widget _modelCard(BuildContext context) {
    return SectionCard(
      title: 'Model health',
      icon: Icons.memory_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv('Messages cached', '${widget.engine.cacheSize}'),
          const SizedBox(height: 10),
          Text(
            'Accuracy, per-class precision/recall and the full confusion '
            'matrix are published in the insights screen.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: widget.onOpenInsights,
            icon: const Icon(Icons.analytics_outlined),
            label: const Text('View model insights'),
          ),
        ],
      ),
    );
  }

  Widget _feedbackCard(BuildContext context, LocalStore? store) {
    final summary = store?.feedbackSummary ?? const <UserFeedback, int>{};
    final total = summary.values.fold<int>(0, (a, b) => a + b);
    final hasData = store != null && total > 0;

    return SectionCard(
      title: 'Your feedback',
      icon: Icons.rate_review_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasData)
            Text(
              'No feedback yet. Rating verdicts on the analysis screen builds '
              'a labelled training set you can export.',
              style: TextStyle(
                height: 1.45,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            _kv('Confirmed correct', '${summary[UserFeedback.confirmed] ?? 0}'),
            _kv('False alarms', '${summary[UserFeedback.falseAlarm] ?? 0}'),
            _kv('Missed threats', '${summary[UserFeedback.missed] ?? 0}'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _export(context, store),
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Export CSV'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    await store.clearFeedback();
                    setState(() {});
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, LocalStore store) async {
    final csv = store.exportFeedbackCsv();

    await Clipboard.setData(ClipboardData(text: csv));

    if (!context.mounted) return;

    final entries = store.feedbackEntries.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied $entries feedback ${entries == 1 ? 'row' : 'rows'} as CSV to '
          'the clipboard.',
        ),
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Expanded(child: Text(key, style: const TextStyle(fontSize: 13.5))),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              fontFeatures: AppTheme.tabularNumbers,
            ),
          ),
        ],
      ),
    );
  }
}