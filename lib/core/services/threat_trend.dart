import '../models/threat_analysis.dart';
import 'threat_engine.dart';

/// Aggregates a set of reports into a dashboard-ready summary.
///
/// A per-message verdict tells a user nothing about whether *this week* is
/// worse than last week. Trend and distribution data is what turns a scanner
/// into a product.
class ThreatTrend {
  final int total;
  final int highRisk;
  final int suspicious;
  final int safe;
  final int critical;

  /// Category -> count, for the distribution chart.
  final Map<ThreatType, int> byType;

  /// Sender -> number of threat messages attributed to it.
  final Map<String, int> topThreatSenders;

  /// Day (midnight, local) -> number of threat messages, for the trend line.
  final Map<DateTime, int> threatsByDay;

  /// Sum of every message's blended risk score. Kept so that
  /// [averageRiskScore] is a pure computation, not hidden mutable state.
  final int totalRiskScore;

  const ThreatTrend({
    required this.total,
    required this.highRisk,
    required this.suspicious,
    required this.safe,
    required this.critical,
    required this.byType,
    required this.topThreatSenders,
    required this.threatsByDay,
    this.totalRiskScore = 0,
  });

  int get threatCount => highRisk + suspicious + critical;

  double get threatRatio => total == 0 ? 0.0 : threatCount / total;

  /// 0..100 headline score: the share of scanned messages that are threats,
  /// weighted so that high-risk items count double.
  int get riskIndex {
    if (total == 0) return 0;

    final weighted = (highRisk * 2) + suspicious + critical * 3;
    final ceiling = total * 3;

    return ((weighted / ceiling) * 100).round().clamp(0, 100);
  }

  /// Average risk score across every scanned message.
  int get averageRiskScore {
    if (total == 0) return 0;
    return (totalRiskScore / total).round();
  }

  static ThreatTrend fromReports(List<MessageThreatReport> reports) {
    var highRisk = 0;
    var suspicious = 0;
    var safe = 0;
    var criticalCount = 0;

    final byType = <ThreatType, int>{
      for (final type in ThreatType.values) type: 0,
    };

    final senders = <String, int>{};
    final byDay = <DateTime, int>{};

    for (final report in reports) {
      final analysis = report.analysis;
      final level = analysis.finalLevel;
      if (level == ThreatLevel.highRisk) {
        highRisk++;
      } else if (level == ThreatLevel.suspicious) {
        suspicious++;
      } else if (level == ThreatLevel.safe) {
        safe++;
      } else if (level == ThreatLevel.critical) {
        criticalCount++;
      }

      byType[analysis.finalType] = (byType[analysis.finalType] ?? 0) + 1;

      if (level != ThreatLevel.safe) {
        final sender = report.message.sender?.trim();
        if (sender != null && sender.isNotEmpty) {
          senders[sender] = (senders[sender] ?? 0) + 1;
        }

        final receivedAt = report.message.receivedAt;
        if (receivedAt != null) {
          final local = receivedAt.toLocal();
          final day = DateTime(local.year, local.month, local.day);
          byDay[day] = (byDay[day] ?? 0) + 1;
        }
      }
    }

    final sortedSenders = senders.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ThreatTrend(
      total: reports.length,
      highRisk: highRisk,
      suspicious: suspicious,
      safe: safe,
      critical: criticalCount,
      byType: byType,
      topThreatSenders: Map.fromEntries(sortedSenders.take(5)),
      threatsByDay: Map.fromEntries(
        byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      ),
      totalRiskScore: reports.fold<int>(
        0,
        (sum, r) => sum + r.analysis.blendedRiskScore,
      ),
    );
  }

  /// The highest-risk reports, worst first.
  static List<MessageThreatReport> highestRisk(
    List<MessageThreatReport> reports, {
    int limit = 5,
  }) {
    final sorted = [...reports]
      ..sort(
        (a, b) =>
            b.analysis.blendedRiskScore.compareTo(a.analysis.blendedRiskScore),
      );

    return sorted.take(limit).toList();
  }
}