import 'package:flutter/material.dart';

import '../../../../core/models/channel_profile.dart';
import '../../../../core/models/message_source.dart';
import '../../../../core/models/protection_mode.dart';
import '../../../../core/models/threat_analysis.dart';
import '../../../../core/services/feedback_calibrator.dart';
import '../../../../core/services/local_store.dart';
import '../../../../core/services/security_alert_service.dart';
import '../../../../core/services/threat_engine.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/threat_widgets.dart';

/// The real-time protection console.
///
/// This is where the app stops being passive: it shows what is being watched,
/// how aggressively suspicious messages are intercepted, and which senders are
/// currently silenced.
class ShieldScreen extends StatelessWidget {
  final ProtectionMode mode;
  final ValueChanged<ProtectionMode> onModeChanged;
  final List<MessageThreatReport> reports;
  final Set<String> mutedSenders;
  final Future<void> Function(String sender) onUnmute;
  final VoidCallback onOpenLinkScanner;
  final bool linkInterceptionEnabled;
  final ValueChanged<bool> onLinkInterceptionChanged;
  final Set<MessageSource> enabledChannels;
  final ValueChanged<Set<MessageSource>> onEnabledChannelsChanged;
  final LocalStore? store;
  final FeedbackCalibrator calibrator;
  final SecurityAlertService alertService;

  const ShieldScreen({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.reports,
    required this.mutedSenders,
    required this.onUnmute,
    required this.onOpenLinkScanner,
    required this.linkInterceptionEnabled,
    required this.onLinkInterceptionChanged,
    required this.enabledChannels,
    required this.onEnabledChannelsChanged,
    this.store,
    this.calibrator = const FeedbackCalibrator(),
    this.alertService = const SecurityAlertService(),
  });

  @override
  Widget build(BuildContext context) {
    final highRisk = reports
        .where((r) => r.analysis.finalLevel == ThreatLevel.highRisk)
        .length;
    final alerts = alertService.detect(reports);
    final advice = calibrator.calibrate(
      summary: store?.feedbackSummary ?? const {},
      currentMode: mode,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _statusCard(context, highRisk),
        if (alerts.isNotEmpty) ...[
          const SizedBox(height: 14),
          _alertsCard(context, alerts),
        ],
        const SizedBox(height: 14),
        _modeCard(context),
        if (advice.shouldSuggestChange) ...[
          const SizedBox(height: 14),
          _calibrationCard(context, advice),
        ],
        const SizedBox(height: 14),
        _linkInterceptionCard(context),
        const SizedBox(height: 14),
        _channelTogglesCard(context),
        const SizedBox(height: 14),
        _mutedCard(context),
        const SizedBox(height: 14),
        _coverageCard(context),
      ],
    );
  }

  Widget _statusCard(BuildContext context, int highRisk) {
    final active = highRisk == 0;

    final color = active ? AppTheme.safeColor : AppTheme.highRiskColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                active ? Icons.shield_outlined : Icons.gpp_maybe_rounded,
                size: 28,
                color: color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    active ? 'Protection active' : 'Action recommended',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    active
                        ? 'No high-risk messages are currently outstanding.'
                        : '$highRisk high-risk message'
                              '${highRisk == 1 ? '' : 's'} need your review.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
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

  Widget _modeCard(BuildContext context) {
    return SectionCard(
      title: 'Detection sensitivity',
      icon: Icons.tune_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<ProtectionMode>(
            segments: [
              for (final value in ProtectionMode.values)
                ButtonSegment(value: value, label: Text(value.label)),
            ],
            selected: {mode},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) onModeChanged(selection.first);
            },
          ),
          const SizedBox(height: 12),
          Text(
            mode.description,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What this changes',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                _thresholdRow(
                  context,
                  'Flag as suspicious from',
                  '${mode.suspiciousScoreFloor}/100',
                ),
                _thresholdRow(
                  context,
                  'Model confidence to decide alone',
                  '${(mode.mlOverrideThreshold * 100).round()}%',
                ),
                _thresholdRow(
                  context,
                  'Rule evidence that outranks the model',
                  '${mode.strongRuleScore}/100',
                ),
                _thresholdRow(
                  context,
                  'Channel risk bonus',
                  mode.applyChannelRisk ? 'Applied' : 'Ignored',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertsCard(BuildContext context, List<SecurityAlert> alerts) {
    return SectionCard(
      title: 'Campaign alerts (${alerts.length})',
      icon: Icons.campaign_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < alerts.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.highRiskColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(
                  color: AppTheme.highRiskColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.gpp_maybe_rounded,
                        size: 17,
                        color: AppTheme.highRiskColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          alerts[i].headline,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: AppTheme.highRiskColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    alerts[i].detail,
                    style: const TextStyle(fontSize: 12.5, height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _calibrationCard(BuildContext context, CalibrationAdvice advice) {
    return SectionCard(
      title: 'Sensitivity suggestion',
      icon: Icons.tune_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            advice.reason,
            style: const TextStyle(fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => onModeChanged(advice.suggestedMode),
                  icon: const Icon(Icons.check_rounded, size: 17),
                  label: Text('Use ${advice.suggestedMode.label}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _thresholdRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5))),
          Text(
            value,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _linkInterceptionCard(BuildContext context) {
    return SectionCard(
      title: 'Link interception',
      icon: Icons.link_off,
      trailing: Switch(
        value: linkInterceptionEnabled,
        onChanged: onLinkInterceptionChanged,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'When enabled, tapping a suspicious link inside the app shows a '
            'pre-flight warning with the real destination domain before '
            'anything opens.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onOpenLinkScanner,
            icon: const Icon(Icons.travel_explore_outlined, size: 17),
            label: const Text('Check a link now'),
          ),
        ],
      ),
    );
  }

  Widget _channelTogglesCard(BuildContext context) {
    final channelProfiles = ChannelProfile.all;

    return SectionCard(
      title: 'Monitored channels',
      icon: Icons.filter_list_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose which sources ThreatGuard scans automatically. A channel '
            'you turn off is not read or monitored, and the inbox is left alone '
            'while SMS is off. Pasting, sharing and scanning links still work '
            'for every channel, because those are things you asked for.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ...channelProfiles.map((profile) {
            final isEnabled = enabledChannels.contains(profile.source);
            return SwitchListTile(
              value: isEnabled,
              onChanged: (value) {
                final newChannels = Set<MessageSource>.from(enabledChannels);
                if (value) {
                  newChannels.add(profile.source);
                } else {
                  newChannels.remove(profile.source);
                }
                onEnabledChannelsChanged(newChannels);
              },
              title: Row(
                children: [
                  Icon(_iconForSource(profile.source), size: 18, color: _colorForSource(profile.source)),
                  const SizedBox(width: 10),
                  Text(profile.displayName, style: const TextStyle(fontSize: 13.5)),
                ],
              ),
              subtitle: Text(
                !isEnabled
                    ? 'Off — not scanned automatically'
                    : profile.isAutomaticallyRead
                    ? 'Automatically scanned from your inbox'
                    : 'Checked when shared to ThreatGuard',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              dense: true,
              contentPadding: EdgeInsets.zero,
            );
          }),
        ],
      ),
    );
  }

  IconData _iconForSource(MessageSource source) {
    switch (source) {
      case MessageSource.sms:
        return Icons.sms_outlined;
      case MessageSource.whatsapp:
        return Icons.chat_outlined;
      case MessageSource.messenger:
        return Icons.message_outlined;
      case MessageSource.instagram:
        return Icons.camera_alt_outlined;
      case MessageSource.email:
        return Icons.email_outlined;
      case MessageSource.web:
        return Icons.language_outlined;
      case MessageSource.clipboard:
        return Icons.content_paste_outlined;
      case MessageSource.manual:
        return Icons.edit_outlined;
      case MessageSource.share:
        return Icons.ios_share_outlined;
    }
  }

  Color _colorForSource(MessageSource source) {
    switch (source) {
      case MessageSource.sms:
        return Colors.green;
      case MessageSource.whatsapp:
        return const Color(0xFF25D366);
      case MessageSource.messenger:
        return const Color(0xFF0084FF);
      case MessageSource.instagram:
        return const Color(0xFFE1306C);
      case MessageSource.email:
        return Colors.blue;
      case MessageSource.web:
        return Colors.deepPurple;
      case MessageSource.clipboard:
        return Colors.orange;
      case MessageSource.manual:
        return Colors.grey;
      case MessageSource.share:
        return Colors.teal;
    }
  }

  Widget _mutedCard(BuildContext context) {
    final muted = mutedSenders.toList()..sort();

    return SectionCard(
      title: 'Muted senders (${muted.length})',
      icon: Icons.volume_off_outlined,
      child: muted.isEmpty
          ? Text(
              'No senders are muted. Long-press any threat message to silence '
              'a sender that only ever sends junk.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : Column(
              children: [
                for (final sender in muted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.sms_outlined, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            sender,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton(
                          onPressed: () => onUnmute(sender),
                          child: const Text('Unmute'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _coverageCard(BuildContext context) {
    return SectionCard(
      title: 'What is being watched',
      icon: Icons.radar_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _coverageRow(
            context,
            Icons.sms_outlined,
            'SMS inbox',
            'Automatic',
            AppTheme.safeColor,
          ),
          _coverageRow(
            context,
            Icons.ios_share_outlined,
            'Any app via the share sheet',
            'WhatsApp, Messenger, Instagram, e-mail, browsers',
            AppTheme.safeColor,
          ),
          _coverageRow(
            context,
            Icons.content_paste_outlined,
            'Pasted messages and links',
            'On demand',
            AppTheme.safeColor,
          ),
          const SizedBox(height: 6),
          Text(
            'Messages inside WhatsApp, Messenger and Instagram cannot be read '
            'automatically — those apps are encrypted and expose no read API. '
            'Sharing to ThreatGuard is how they get checked.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverageRow(
    BuildContext context,
    IconData icon,
    String title,
    String detail,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
