import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/threatguard_ui_tokens.dart';

class ThreatGuardGlassPanel extends StatelessWidget {
  const ThreatGuardGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
    this.glowColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final glow = glowColor ?? ThreatGuardUiTokens.primary;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.07),
            blurRadius: 26,
            spreadRadius: -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: ThreatGuardUiTokens.surface.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: ThreatGuardUiTokens.border.withValues(alpha: 0.8),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
