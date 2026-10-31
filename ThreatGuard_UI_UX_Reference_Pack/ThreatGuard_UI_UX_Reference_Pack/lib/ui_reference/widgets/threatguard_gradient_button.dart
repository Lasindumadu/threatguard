import 'package:flutter/material.dart';
import '../theme/threatguard_ui_tokens.dart';
import '../motion/threatguard_motion.dart';

/// Visual button component. Wire an existing app action to onPressed during integration.
class ThreatGuardGradientButton extends StatelessWidget {
  const ThreatGuardGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = AnimatedContainer(
      duration: ThreatGuardMotion.quick,
      curve: ThreatGuardMotion.standardCurve,
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? const LinearGradient(
                colors: [Color(0xFF43576D), Color(0xFF34485E)],
              )
            : ThreatGuardUiTokens.primaryGradient,
        borderRadius: BorderRadius.circular(17),
        boxShadow: onPressed == null
            ? const []
            : [
                BoxShadow(
                  color: ThreatGuardUiTokens.primary.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: ThreatGuardUiTokens.background, size: 19),
                  const SizedBox(width: 9),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: ThreatGuardUiTokens.background,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return button;
  }
}
