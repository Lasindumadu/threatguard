import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class CyberSplashGate extends StatefulWidget {
  final Widget child;
  final Duration minDuration;

  const CyberSplashGate({
    super.key,
    required this.child,
    this.minDuration = const Duration(milliseconds: 500),
  });

  @override
  State<CyberSplashGate> createState() => _CyberSplashGateState();
}

class _CyberSplashGateState extends State<CyberSplashGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    final isTestEnvironment = WidgetsBinding.instance is! WidgetsFlutterBinding;
    if (!isTestEnvironment) {
      _controller.repeat();
    }

    if (isTestEnvironment || widget.minDuration == Duration.zero) {
      _ready = true;
    } else {
      Future.delayed(widget.minDuration, () {
        if (mounted) {
          setState(() => _ready = true);
        }
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _ready
          ? widget.child
          : _SplashScreenBody(controller: _controller),
    );
  }
}

class _SplashScreenBody extends StatelessWidget {
  final AnimationController controller;

  const _SplashScreenBody({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070D12) : const Color(0xFFF2F6FA),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _CyberGridPainter(
              color: AppTheme.accent.withValues(alpha: isDark ? 0.08 : 0.04),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 170,
                  height: 170,
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _RadarPainter(
                          progress: controller.value,
                          color: AppTheme.accent,
                        ),
                        child: Center(
                          child: Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                colors: [
                                  Color(0xFF0F3A4B),
                                  Color(0xFF071C24),
                                ],
                              ),
                              border: Border.all(
                                color: AppTheme.accent.withValues(alpha: 0.6),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.accent.withValues(alpha: 0.35),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.security_rounded,
                              size: 44,
                              color: AppTheme.accent,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'THREATGUARD',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.5,
                    color: isDark ? Colors.white : const Color(0xFF0D1E2D),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.safeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI Threat Intelligence Engine',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isDark
                            ? const Color(0xFF7E92A4)
                            : const Color(0xFF4C5D6E),
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadarPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var i = 1; i <= 4; i++) {
      final r = maxRadius * (i / 4);
      ringPaint.color = color.withValues(alpha: 0.08 * i);
      canvas.drawCircle(center, r, ringPaint);
    }

    // Crosshairs
    final crossPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(center.dx - maxRadius, center.dy), Offset(center.dx + maxRadius, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius), Offset(center.dx, center.dy + maxRadius), crossPaint);

    final sweepAngle = math.pi / 2.0;
    final startAngle = progress * 2 * math.pi;

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: FractionalOffset.center,
        startAngle: 0.0,
        endAngle: sweepAngle,
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.45),
        ],
        transform: GradientRotation(startAngle),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: maxRadius),
      startAngle,
      sweepAngle,
      true,
      sweepPaint,
    );

    // Blip dots on radar
    final blipPositions = [
      Offset(center.dx + maxRadius * 0.45 * math.cos(progress * 2 * math.pi - 0.4), center.dy + maxRadius * 0.45 * math.sin(progress * 2 * math.pi - 0.4)),
      Offset(center.dx + maxRadius * 0.75 * math.cos(progress * 2 * math.pi - 0.9), center.dy + maxRadius * 0.75 * math.sin(progress * 2 * math.pi - 0.9)),
    ];

    final blipPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < blipPositions.length; i++) {
      blipPaint.color = i == 0 ? const Color(0xFF00FFB2) : const Color(0xFFFF5252);
      canvas.drawCircle(blipPositions[i], 3.5, blipPaint);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _CyberGridPainter extends CustomPainter {
  final Color color;

  _CyberGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const step = 34.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_CyberGridPainter oldDelegate) =>
      oldDelegate.color != color;
}
