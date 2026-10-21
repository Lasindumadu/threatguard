import 'package:flutter/material.dart';

import '../models/hybrid_threat_analysis.dart';
import '../models/ml_feature_vector.dart';
import '../models/threat_analysis.dart';
import '../theme/app_theme.dart';
import 'motion.dart';

/// Circular 0-100 risk dial used as the hero element on the detail screen.
///
/// Delegates to [AnimatedRingGauge] so the dial, the dashboard hero and the
/// posture score all share one animation curve.
class RiskGauge extends StatelessWidget {
  final int score;
  final ThreatLevel level;
  final double size;

  const RiskGauge({
    super.key,
    required this.score,
    required this.level,
    this.size = 152,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.levelColor(level);

    return AnimatedRingGauge(
      score: score,
      color: color,
      size: size,
      centerIcon: AppTheme.levelIcon(level),
    );
  }
}

/// A labelled horizontal bar, used for the per-class probability breakdown.
class MetricBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final String? trailing;

  const MetricBar({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                trailing ?? '${(value * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedBar(value: value, color: color),
        ],
      ),
    );
  }
}

/// The per-class probability distribution from the model — the "why" behind
/// the label. Showing this instead of a single confidence number is what makes
/// the model auditable rather than magic.
class ProbabilityBreakdown extends StatelessWidget {
  final HybridThreatAnalysis analysis;

  const ProbabilityBreakdown({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final distribution = analysis.mlPrediction.distribution;

    if (distribution.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.insights_outlined, size: 18),
            const SizedBox(width: 8),
            const Text(
              'How the model scored this',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Probability assigned to each category. Close values mean the '
          'message sits between categories.',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        for (final entry in entries)
          MetricBar(
            label: AppTheme.typeLabel(_toThreatType(entry.key)),
            value: entry.value,
            color: AppTheme.typeColor(_toThreatType(entry.key)),
          ),
        const SizedBox(height: 8),
        _decisivenessNote(context),
      ],
    );
  }

  Widget _decisivenessNote(BuildContext context) {
    final margin = analysis.mlPrediction.margin;
    final confidence = analysis.mlPrediction.confidence;

    final (text, icon, color) = margin >= 0.35
        ? (
            'The model is decisive about this classification.',
            Icons.check_circle_outline,
            AppTheme.safeColor,
          )
        : margin >= 0.10
        ? (
            'The model is reasonably confident, but this sits near another '
                'category.',
            Icons.info_outline,
            AppTheme.suspiciousColor,
          )
        : (
            'The top two categories are very close — treat the label as a '
                'best guess, not a certainty.',
            Icons.help_outline,
            AppTheme.suspiciousColor,
          );

    return Builder(
      builder: (context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$text (top score '
              '${(confidence * 100).toStringAsFixed(1)}%)',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  ThreatType _toThreatType(MlThreatType type) => switch (type) {
    MlThreatType.legitimate => ThreatType.legitimate,
    MlThreatType.spam => ThreatType.spam,
    MlThreatType.phishing => ThreatType.phishing,
    MlThreatType.scam => ThreatType.scam,
    MlThreatType.socialEngineering => ThreatType.socialEngineering,
  };
}

/// Small pill showing a threat category.
class TypeBadge extends StatelessWidget {
  final ThreatType type;
  final bool compact;

  const TypeBadge({super.key, required this.type, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.typeColor(type);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppTheme.typeIcon(type), size: compact ? 12 : 14, color: color),
          const SizedBox(width: 5),
          Text(
            compact ? AppTheme.typeShortLabel(type) : AppTheme.typeLabel(type),
            style: TextStyle(
              fontSize: compact ? 11 : 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact risk pill: "High risk · 78/100".
class RiskChip extends StatelessWidget {
  final int score;
  final ThreatLevel level;

  const RiskChip({super.key, required this.score, required this.level});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.levelColor(level);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(AppTheme.levelIcon(level), size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          '${AppTheme.levelLabel(level)} · $score/100',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// A card with a titled header, used across every screen for consistency.
class SectionCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 15, color: scheme.primary),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// Consistent empty/error state block.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  /// Draws a slow pulse around the icon. Reserved for states that genuinely
  /// want the user to act (a scan they have not run yet), not for ordinary
  /// empty lists — a pulsing icon becomes wallpaper within seconds.
  final bool celebrate;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actions = const [],
    this.celebrate = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accentColor = celebrate ? AppTheme.safeColor : scheme.primary;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AttentionPulse(
              color: accentColor,
              enabled: celebrate,
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.16),
                      accentColor.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(icon, size: 42, color: accentColor),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                height: 1.5,
                fontSize: 13.5,
              ),
            ),
            if (actions.isNotEmpty) ...[const SizedBox(height: 24), ...actions],
          ],
        ),
      ),
    );
  }
}

/// A hand-painted 7-day threat sparkline.
///
/// Deliberately dependency-free: pulling in a charting package for a single
/// sparkline would add a large surface area for a tiny visual gain, and a
/// custom painter gives exact control over how the trend reads.
class TimelineChart extends StatelessWidget {
  /// Day (midnight local) -> threat count.
  final Map<DateTime, int> data;

  /// How many days to display, ending today.
  final int days;

  final double height;

  const TimelineChart({
    super.key,
    required this.data,
    this.days = 7,
    this.height = 72,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = today.subtract(Duration(days: days - 1));

    final series = <DateTime, int>{};
    for (var i = 0; i < days; i++) {
      final day = DateTime(start.year, start.month, start.day + i);
      series[day] = data[day] ?? 0;
    }

    final peak = series.values.fold<int>(0, (a, b) => a > b ? a : b);

    if (peak == 0) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No threat activity in the last $days days.',
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final color = Theme.of(context).colorScheme.primary;

    return Semantics(
      label:
          'Threat activity over the last $days days. Peak $peak in a single '
          'day.',
      child: SizedBox(
        height: height,
        child: CustomPaint(
          painter: _SparklinePainter(
            values: series.values.toList(),
            peak: peak,
            color: color,
            gridColor: Theme.of(context).dividerColor,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<int> values;
  final int peak;
  final Color color;
  final Color gridColor;

  const _SparklinePainter({
    required this.values,
    required this.peak,
    required this.color,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    const padding = 6.0;
    final width = size.width - padding * 2;
    final baseline = size.height - padding;
    final usableHeight = size.height - padding * 2;

    // Baseline.
    canvas.drawLine(
      Offset(padding, baseline),
      Offset(size.width - padding, baseline),
      Paint()
        ..color = gridColor
        ..strokeWidth = 1,
    );

    final step = values.length <= 1 ? 0.0 : width / (values.length - 1);

    final barWidth = (step == 0 ? width : step) * 0.5;

    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == 0) continue;

      final barHeight = (value / peak) * usableHeight;
      final x = padding + step * i;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x - barWidth / 2,
          baseline - barHeight,
          barWidth,
          barHeight,
        ),
        const Radius.circular(3),
      );

      canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: 0.85));
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.peak != peak ||
      old.color != color ||
      !_sameValues(old.values, values);

  static bool _sameValues(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The dashboard hero: one 0-100 posture score, its grade, and the weakest
/// contributing area named explicitly.
class SecurityScoreHero extends StatelessWidget {
  final int score;
  final String headline;
  final String advice;
  final int highRiskCount;
  final int suspiciousCount;

  const SecurityScoreHero({
    super.key,
    required this.score,
    required this.headline,
    required this.advice,
    required this.highRiskCount,
    required this.suspiciousCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final color = score >= 70
        ? AppTheme.safeColor
        : score >= 45
        ? AppTheme.suspiciousColor
        : AppTheme.highRiskColor;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF16232E), const Color(0xFF101820)]
              : [Colors.white, const Color(0xFFF0F5F9)],
        ),
        border: Border.all(color: color.withValues(alpha: 0.28), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.16 : 0.10),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SECURITY SCORE', style: AppTheme.overline(context)),
            const SizedBox(height: 14),
            Row(
              children: [
                AnimatedRingGauge(score: score, color: color, size: 122),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: color,
                          height: 1.22,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _pill(
                            context,
                            Icons.gpp_maybe_rounded,
                            '$highRiskCount',
                            AppTheme.highRiskColor,
                          ),
                          const SizedBox(width: 8),
                          _pill(
                            context,
                            Icons.warning_amber_rounded,
                            '$suspiciousCount',
                            AppTheme.suspiciousColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              advice,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, IconData icon, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            count,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// What the verdict is built on, split into facts and judgements.
///
/// This card exists because a verdict without its basis is a guess. Each line
/// is written in the register its evidence supports: observed text is quoted,
/// structural inferences are listed as inferences, and the things ThreatGuard
/// cannot know — above all, whether the sender is who they claim — are stated
/// as unknown instead of being quietly assumed.
class EvidenceProvenanceCard extends StatelessWidget {
  final EvidenceSummary summary;

  const EvidenceProvenanceCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'What this verdict rests on',
      icon: Icons.fact_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summary.known.isNotEmpty)
            _group(
              context,
              'Observed in the message',
              summary.known,
              Icons.visibility_outlined,
              AppTheme.suspiciousColor,
            ),
          if (summary.inferred.isNotEmpty) ...[
            if (summary.known.isNotEmpty) const SizedBox(height: 12),
            _group(
              context,
              'Inferred — could be wrong',
              summary.inferred,
              Icons.insights_outlined,
              AppTheme.suspiciousColor,
            ),
          ],
          // Counter-evidence: wording that makes the message look genuine. It
          // was computed and never rendered, so a "suspicious" verdict hid the
          // facts pointing the other way.
          if (summary.supports.isNotEmpty) ...[
            if (summary.known.isNotEmpty || summary.inferred.isNotEmpty)
              const SizedBox(height: 12),
            _group(
              context,
              'Points the other way',
              summary.supports,
              Icons.balance_outlined,
              AppTheme.safeColor,
            ),
          ],
          if (summary.unknown.isNotEmpty) ...[
            const SizedBox(height: 12),
            _group(
              context,
              'Not known',
              summary.unknown,
              Icons.help_outline,
              Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
          if (summary.known.isEmpty &&
              summary.inferred.isEmpty &&
              summary.unknown.isEmpty &&
              summary.supports.isEmpty)
            const Text('Nothing specific was detected.'),
        ],
      ),
    );
  }

  Widget _group(
    BuildContext context,
    String label,
    List<String> items,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icon(icon, size: 13, color: color),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
