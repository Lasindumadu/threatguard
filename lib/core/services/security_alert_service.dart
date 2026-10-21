import '../models/threat_analysis.dart';
import 'threat_engine.dart';

/// One escalated warning: repeated high-risk messages from a single sender.
///
/// Showing N separate inbox rows buries the pattern. An alert names it:
/// "a campaign is targeting you".
class SecurityAlert {
  final String sender;
  final int highRiskCount;
  final int totalCount;
  final DateTime? latestAt;
  final List<MessageThreatReport> reports;

  const SecurityAlert({
    required this.sender,
    required this.highRiskCount,
    required this.totalCount,
    required this.latestAt,
    required this.reports,
  });

  String get headline => 'Repeated attacks from $sender';

  String get detail =>
      '$highRiskCount high-risk ${highRiskCount == 1 ? 'message' : 'messages'} '
      'from this sender${latestAt == null ? '' : ' — latest just now'}. '
      'This looks like a targeted campaign, not isolated spam.';
}

/// Raises [SecurityAlert]s from repeated high-risk traffic.
///
/// Pure-Dart and deliberately conservative: an alert needs at least
/// [minHighRisk] high-risk messages from the same sender, optionally inside
/// [window]. This keeps one angry promo sender from raising a campaign alert.
class SecurityAlertService {
  const SecurityAlertService();

  static const int minHighRisk = 3;
  static const Duration window = Duration(days: 7);

  List<SecurityAlert> detect(
    List<MessageThreatReport> reports, {
    int minHighRisk = SecurityAlertService.minHighRisk,
    Duration window = SecurityAlertService.window,
    DateTime? now,
  }) {
    final reference = (now ?? DateTime.now()).toLocal();
    final cutoff = reference.subtract(window);

    final bySender = <String, List<MessageThreatReport>>{};
    for (final report in reports) {
      if (report.analysis.finalLevel != ThreatLevel.highRisk) continue;
      final received = report.message.receivedAt?.toLocal();
      if (received != null && received.isBefore(cutoff)) continue;
      final sender = (report.message.sender ?? '').trim();
      if (sender.isEmpty) continue;
      bySender.putIfAbsent(sender, () => []).add(report);
    }

    final alerts = <SecurityAlert>[];
    for (final entry in bySender.entries) {
      if (entry.value.length < minHighRisk) continue;
      final sorted = [...entry.value]
        ..sort((a, b) {
          final at = a.message.receivedAt;
          final bt = b.message.receivedAt;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        });
      alerts.add(
        SecurityAlert(
          sender: entry.key,
          highRiskCount: sorted.length,
          totalCount: sorted.length,
          latestAt: sorted.first.message.receivedAt,
          reports: List.unmodifiable(sorted),
        ),
      );
    }

    alerts.sort((a, b) => b.highRiskCount.compareTo(a.highRiskCount));
    return alerts;
  }
}
