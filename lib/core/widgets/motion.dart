import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Staggered entrance: children rise and fade in sequence.
///
/// The default `AnimatedList` is rigid and needs a controller; this is a
/// lighter, composable alternative for a fixed set of children. The stagger is
/// capped so a long list does not crawl — item 20 arrives as fast as item 4.
class StaggeredEntrance extends StatelessWidget {
  final List<Widget> children;
  final Duration delay;
  final double offset;

  const StaggeredEntrance({
    super.key,
    required this.children,
    this.delay = const Duration(milliseconds: 55),
    this.offset = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++)
          _StaggerItem(
            index: i,
            delay: delay,
            offset: offset,
            child: children[i],
          ),
      ],
    );
  }
}

class _StaggerItem extends StatefulWidget {
  final int index;
  final Duration delay;
  final double offset;
  final Widget child;

  const _StaggerItem({
    required this.index,
    required this.delay,
    required this.offset,
    required this.child,
  });

  @override
  State<_StaggerItem> createState() => _StaggerItemState();
}

class _StaggerItemState extends State<_StaggerItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: AppTheme.motionSlow,
    );

    // Cap the stagger at 8 steps: beyond that the last item would arrive
    // noticeably late for no benefit.
    final step = math.min(widget.index, 8);

    Future<void>.delayed(widget.delay * step, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: AppTheme.motionCurve,
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - curved.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Press feedback wrapper: scales the child down slightly while held.
///
/// Cheap, tactile, and applied consistently so every tappable surface in the
/// app behaves the same way.
class PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final bool haptic;

  const PressableCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(16),
    this.haptic = true,
  });

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) {
                  HapticFeedback.selectionClick().catchError((_) {});
                }
                widget.onTap!();
              },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                if (widget.haptic) {
                  HapticFeedback.mediumImpact().catchError((_) {});
                }
                widget.onLongPress!();
              },
        child: AnimatedScale(
          scale: _pressed ? 0.978 : 1.0,
          duration: AppTheme.motionFast,
          curve: AppTheme.motionCurve,
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Animated count-up for headline numbers.
///
/// Large values that snap into place feel broken; a short count-up makes the
/// score read as a measurement rather than a static label.
class CountUpText extends StatelessWidget {
  final int value;
  final TextStyle style;
  final Duration duration;
  final String? suffix;

  const CountUpText({
    super.key,
    required this.value,
    required this.style,
    this.duration = AppTheme.motionSlow,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) =>
          Text('${animated.round()}${suffix ?? ''}', style: style),
    );
  }
}

/// A ring gauge with an animated sweep and a rotating highlight.
///
/// Used for headline scores. The dial animation is the single most visible
/// motion in the app, so it runs on a slightly longer curve than everything
/// else — it should feel like a needle settling.
class AnimatedRingGauge extends StatelessWidget {
  final int score;
  final Color color;
  final double size;
  final String? centerLabel;
  final String? centerSubLabel;
  final IconData? centerIcon;

  const AnimatedRingGauge({
    super.key,
    required this.score,
    required this.color,
    this.size = 152,
    this.centerLabel,
    this.centerSubLabel,
    this.centerIcon,
  });

  @override
  Widget build(BuildContext context) {
    final trackColor = Theme.of(context).dividerColor;

    return Semantics(
      label: '$centerLabel, score $score out of 100',
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: score / 100),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return CustomPaint(
              painter: _RingPainter(
                progress: value,
                color: color,
                trackColor: trackColor,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (centerIcon != null)
                      Icon(centerIcon, size: size * 0.16, color: color),
                    Text(
                      centerLabel ?? '${(value * 100).round()}',
                      style: TextStyle(
                        fontSize: size * 0.25,
                        fontWeight: FontWeight.w800,
                        color: color,
                        height: 1.0,
                        letterSpacing: -1,
                      ),
                    ),
                    if (centerSubLabel != null)
                      Text(
                        centerSubLabel!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 13.0;
    final rect = (Offset.zero & size).deflate(stroke / 2 + 2);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    // A subtle glow behind the value arc, so the gauge reads as lit.
    final glow = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    const start = -math.pi / 2;
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);

    canvas.drawArc(rect, start, 2 * math.pi, false, track);

    if (sweep > 0.001) {
      canvas.drawArc(rect, start, sweep, false, glow);
      canvas.drawArc(rect, start, sweep, false, arc);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

/// Animated horizontal bar, for probability and metric breakdowns.
class AnimatedBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;

  const AnimatedBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 7,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 680),
        curve: Curves.easeOutCubic,
        builder: (context, animated, _) => Stack(
          children: [
            Container(height: height, color: Theme.of(context).dividerColor),
            FractionallySizedBox(
              widthFactor: animated,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.75), color],
                  ),
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A pulse that draws attention without animating forever.
///
/// Three beats and it stops: an infinitely pulsing element becomes wallpaper
/// within seconds and stops signalling anything.
class AttentionPulse extends StatefulWidget {
  final Widget child;
  final Color color;
  final bool enabled;

  const AttentionPulse({
    super.key,
    required this.child,
    required this.color,
    this.enabled = true,
  });

  @override
  State<AttentionPulse> createState() => _AttentionPulseState();
}

class _AttentionPulseState extends State<AttentionPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    if (widget.enabled) {
      _controller.forward().then((_) {
        if (!mounted) return;
        _controller.repeat(reverse: true, count: 3);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.10 + 0.22 * t),
                blurRadius: 12 + 16 * t,
                spreadRadius: 1 + 3 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A horizontally scrolling distribution bar: the whole, split by category.
///
/// Replaces a stack of five progress bars with one element that reads the same
/// information in a single glance.
class DistributionBar extends StatelessWidget {
  final Map<String, ({int count, Color color})> segments;
  final double height;

  const DistributionBar({super.key, required this.segments, this.height = 14});

  @override
  Widget build(BuildContext context) {
    final visible = segments.entries.where((e) => e.value.count > 0).toList();
    final total = visible.fold<int>(0, (sum, e) => sum + e.value.count);

    if (total == 0) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      );
    }

    return Semantics(
      label:
          'Distribution: ${visible.map((e) => '${e.key} ${e.value.count}').join(', ')}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              for (final entry in visible)
                Expanded(
                  flex: entry.value.count,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: AppTheme.motionSlow,
                    curve: AppTheme.motionCurve,
                    builder: (context, t, _) => Container(
                      margin: const EdgeInsets.only(right: 1.5),
                      decoration: BoxDecoration(
                        color: entry.value.color.withValues(
                          alpha: 0.55 + 0.45 * t,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The shield mark used in the app bar and empty states.
///
/// Drawn rather than imported so the product has an identity mark that is not
/// an off-the-shelf icon.
class ThreatGuardMark extends StatelessWidget {
  final double size;
  final Color? color;
  final bool glow;

  const ThreatGuardMark({
    super.key,
    this.size = 40,
    this.color,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final paintColor = color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MarkPainter(color: paintColor, glow: glow),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  final Color color;
  final bool glow;

  const _MarkPainter({required this.color, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // A shield outline: flat top, tapering to a point, with a notch.
    final path = Path()
      ..moveTo(w * 0.5, h * 0.04)
      ..lineTo(w * 0.93, h * 0.22)
      ..lineTo(w * 0.93, h * 0.52)
      ..quadraticBezierTo(w * 0.93, h * 0.82, w * 0.5, h * 0.97)
      ..quadraticBezierTo(w * 0.07, h * 0.82, w * 0.07, h * 0.52)
      ..lineTo(w * 0.07, h * 0.22)
      ..close();

    if (glow) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.72)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // The inner check, drawn as a stroke so it scales with the shield.
    final check = Path()
      ..moveTo(w * 0.31, h * 0.50)
      ..lineTo(w * 0.44, h * 0.63)
      ..lineTo(w * 0.70, h * 0.35);

    canvas.drawPath(
      check,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.085
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.color != color || old.glow != glow;
}
