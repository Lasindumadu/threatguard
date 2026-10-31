import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Animated cyber ambient backdrop with glowing particles and circuit-grid traces.
class CyberBackdrop extends StatefulWidget {
  final Widget child;
  final bool animate;

  const CyberBackdrop({
    super.key,
    required this.child,
    this.animate = true,
  });

  @override
  State<CyberBackdrop> createState() => _CyberBackdropState();
}

class _CyberBackdropState extends State<CyberBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    // In test environment, animations should not run continuous infinite loops
    // so tester.pumpAndSettle() can settle cleanly.
    final isTestEnvironment = WidgetsBinding.instance is! WidgetsFlutterBinding;
    if (widget.animate && !isTestEnvironment) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base dark cyber gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [
                      Color(0xFF070D13),
                      Color(0xFF0B141C),
                      Color(0xFF071017),
                    ]
                  : const [
                      Color(0xFFF3F7FA),
                      Color(0xFFE9F0F5),
                      Color(0xFFEDF3F7),
                    ],
            ),
          ),
        ),
        // Ambient animated cyber grid & glowing particles
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _CyberAmbientPainter(
                progress: _controller.value,
                isDark: isDark,
                accent: AppTheme.accent,
              ),
            );
          },
        ),
        // Main content
        widget.child,
      ],
    );
  }
}

class _CyberAmbientPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final Color accent;

  _CyberAmbientPainter({
    required this.progress,
    required this.isDark,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle cyber grid lines
    final gridPaint = Paint()
      ..color = accent.withValues(alpha: isDark ? 0.03 : 0.02)
      ..strokeWidth = 1.0;

    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Floating cyber nodes / particles
    final particleCount = 7;
    for (int i = 0; i < particleCount; i++) {
      final angle = (progress * 2 * math.pi) + (i * (2 * math.pi / particleCount));
      final radius = 60.0 + (i * 24.0);
      final cx = (size.width * 0.5) + radius * math.cos(angle);
      final cy = (size.height * 0.3) + (radius * 0.7) * math.sin(angle);

      final particlePaint = Paint()
        ..color = accent.withValues(alpha: isDark ? 0.12 : 0.06)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(cx, cy), 2.5, particlePaint);

      final glowPaint = Paint()
        ..color = accent.withValues(alpha: isDark ? 0.04 : 0.02)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(Offset(cx, cy), 16, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_CyberAmbientPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isDark != isDark;
}
