import 'package:flutter/material.dart';
import '../theme/threatguard_ui_tokens.dart';

/// Decorative animated shield. The caller can disable animation to respect
/// the app's existing Reduce animations setting.
class ThreatGuardPulseShield extends StatefulWidget {
  const ThreatGuardPulseShield({
    super.key,
    this.size = 116,
    this.animate = true,
  });

  final double size;
  final bool animate;

  @override
  State<ThreatGuardPulseShield> createState() => _ThreatGuardPulseShieldState();
}

class _ThreatGuardPulseShieldState extends State<ThreatGuardPulseShield>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant ThreatGuardPulseShield oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = widget.animate ? _controller.value : 0.25;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                ThreatGuardUiTokens.primary.withValues(alpha: 0.18 + t * 0.12),
                ThreatGuardUiTokens.primary.withValues(alpha: 0.02),
                Colors.transparent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: ThreatGuardUiTokens.primary.withValues(alpha: 0.08 + t * 0.12),
                blurRadius: 20 + t * 18,
                spreadRadius: 2 + t * 3,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: widget.size * 0.66,
              height: widget.size * 0.66,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.size * 0.23),
                gradient: ThreatGuardUiTokens.shieldGradient,
                boxShadow: [
                  BoxShadow(
                    color: ThreatGuardUiTokens.primary.withValues(alpha: 0.22),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Icon(
                Icons.verified_user_rounded,
                size: widget.size * 0.38,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}
