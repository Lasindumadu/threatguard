import 'package:flutter/material.dart';
import '../theme/threatguard_ui_tokens.dart';
import '../widgets/threatguard_glass_panel.dart';
import '../widgets/threatguard_gradient_button.dart';
import '../widgets/threatguard_pulse_shield.dart';

/// A UI-only reference screen. Demo values are decorative and must not replace
/// the app's real security state or detection results.
class ThreatGuardDashboardVisualReference extends StatelessWidget {
  const ThreatGuardDashboardVisualReference({
    super.key,
    this.onScanPressed,
    this.reduceAnimations = false,
  });

  final VoidCallback? onScanPressed;
  final bool reduceAnimations;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThreatGuardUiTokens.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/cyber_navy_wave.jpg',
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.48),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Row(
                        children: [
                          const ThreatGuardPulseShield(
                            size: 42,
                            animate: false,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ThreatGuard',
                                  style: TextStyle(
                                    color: ThreatGuardUiTokens.textPrimary,
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'YOUR DIGITAL SAFETY',
                                  style: TextStyle(
                                    color: ThreatGuardUiTokens.textSecondary,
                                    fontSize: 10,
                                    letterSpacing: 1.7,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(
                              Icons.notifications_none_rounded,
                              color: ThreatGuardUiTokens.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const ThreatGuardGlassPanel(
                        glowColor: ThreatGuardUiTokens.success,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Protection status',
                                    style: TextStyle(
                                      color: ThreatGuardUiTokens.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'You’re protected',
                                    style: TextStyle(
                                      color: ThreatGuardUiTokens.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    'Visual sample status only',
                                    style: TextStyle(
                                      color: ThreatGuardUiTokens.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ThreatGuardPulseShield(size: 76, animate: false),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Center(
                        child: ThreatGuardPulseShield(
                          size: 142,
                          animate: !reduceAnimations,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'SECURITY CENTER',
                          style: TextStyle(
                            color: ThreatGuardUiTokens.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ThreatGuardGradientButton(
                        label: 'Start visual scan',
                        icon: Icons.radar_rounded,
                        onPressed: onScanPressed,
                      ),
                      const SizedBox(height: 22),
                      const Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              icon: Icons.shield_outlined,
                              label: 'Items checked',
                              value: '1,248',
                              accent: ThreatGuardUiTokens.primary,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              icon: Icons.gpp_bad_outlined,
                              label: 'Threats flagged',
                              value: '12',
                              accent: ThreatGuardUiTokens.danger,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Recent activity',
                        style: TextStyle(
                          color: ThreatGuardUiTokens.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _ActivityRow(
                        icon: Icons.link_rounded,
                        title: 'Link analysis',
                        subtitle: 'Example activity row',
                        color: ThreatGuardUiTokens.warning,
                      ),
                      const SizedBox(height: 10),
                      const _ActivityRow(
                        icon: Icons.verified_rounded,
                        title: 'Protection check',
                        subtitle: 'Example activity row',
                        color: ThreatGuardUiTokens.success,
                      ),
                      const SizedBox(height: 10),
                      const _ActivityRow(
                        icon: Icons.warning_amber_rounded,
                        title: 'Threat review',
                        subtitle: 'Example activity row',
                        color: ThreatGuardUiTokens.danger,
                      ),
                    ]),
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ThreatGuardGlassPanel(
      padding: const EdgeInsets.all(15),
      glowColor: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              color: ThreatGuardUiTokens.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: ThreatGuardUiTokens.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ThreatGuardGlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ThreatGuardUiTokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ThreatGuardUiTokens.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: ThreatGuardUiTokens.textMuted,
          ),
        ],
      ),
    );
  }
}
