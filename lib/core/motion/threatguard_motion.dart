import 'package:flutter/material.dart';

/// Motion timings and curves for decorative UI transitions.
/// Respect the app's existing Reduce animations preference when integrating.
abstract final class ThreatGuardMotion {
  static const Duration quick = Duration(milliseconds: 160);
  static const Duration standard = Duration(milliseconds: 260);
  static const Duration emphasis = Duration(milliseconds: 420);
  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve enterCurve = Curves.easeOutBack;
}

/// Fade + upward movement for cards and sections.
class ThreatGuardFadeSlide extends StatelessWidget {
  const ThreatGuardFadeSlide({
    super.key,
    required this.child,
    required this.animation,
    this.distance = 14,
  });

  final Widget child;
  final Animation<double> animation;
  final double distance;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: ThreatGuardMotion.standardCurve,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, distance / 100),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
