import '../models/security_posture.dart';
import 'threat_engine.dart';
import 'threat_trend.dart';

/// The single headline number on the dashboard.
///
/// Composing four independent domains into one score is a deliberate product
/// decision: users cannot hold four numbers in their head, and the whole point
/// of the dashboard is to answer "am I okay?" in one glance. The cost is that a
/// composite can hide detail — so the score always ships with its contributors
/// broken out, and [largestContributor] names the weakest area explicitly.
class CompoundSecurityScore {
  /// 0..100 each.
  final int messageRisk;
  final int linkExposure;
  final int accountHygiene;
  final int devicePosture;

  final ThreatTrend trend;
  final SecurityPosture posture;

  const CompoundSecurityScore({
    required this.messageRisk,
    required this.linkExposure,
    required this.accountHygiene,
    required this.devicePosture,
    required this.trend,
    required this.posture,
  });

  /// Weighted blend. Message risk carries the most weight because that is what
  /// this app actually measures directly.
  int get overall {
    final weighted =
        (messageRisk * 0.40) +
        (linkExposure * 0.20) +
        (accountHygiene * 0.20) +
        (devicePosture * 0.20);

    return weighted.round().clamp(0, 100);
  }

  ScoreGrade get grade => switch (overall) {
    >= 85 => ScoreGrade.excellent,
    >= 70 => ScoreGrade.good,
    >= 50 => ScoreGrade.fair,
    >= 30 => ScoreGrade.weak,
    _ => ScoreGrade.critical,
  };

  /// Which area is dragging the score down the most, for the call to action.
  ScoreContributor get largestContributor {
    final entries = <ScoreContributor, int>{
      ScoreContributor.messages: messageRisk,
      ScoreContributor.links: linkExposure,
      ScoreContributor.accounts: accountHygiene,
      ScoreContributor.device: devicePosture,
    };

    return entries.entries.reduce((a, b) => a.value <= b.value ? a : b).key;
  }

  String get headline => switch (grade) {
    ScoreGrade.excellent => 'Your security posture is strong',
    ScoreGrade.good => 'You are in good shape',
    ScoreGrade.fair => 'There are gaps worth closing',
    ScoreGrade.weak => 'Several risks need attention',
    ScoreGrade.critical => 'Act on these warnings soon',
  };

  String get advice {
    if (trend.total == 0) {
      return 'Nothing has been scanned yet, so this score only reflects your '
          'settings. Grant access or share a message to start.';
    }

    return switch (largestContributor) {
      ScoreContributor.messages =>
        'Message threats are your weakest area. Review the flagged messages on '
            'the dashboard, and consider Strict mode.',
      ScoreContributor.links =>
        'Links in your messages are the biggest concern. Run unfamiliar links '
            'through the Link scanner before tapping.',
      ScoreContributor.accounts =>
        'Account hygiene is your weakest area. Check your address in Breach '
            'check and give every account a unique password.',
      ScoreContributor.device =>
        'Device settings need attention. Work through the checklist in '
            'Device posture.',
    };
  }

  static CompoundSecurityScore compute({
    required List<MessageThreatReport> reports,
    required SecurityPosture posture,
  }) {
    final trend = ThreatTrend.fromReports(reports);

    // Message risk: inverted threat ratio. A 0% threat rate is 100 points.
    final messageRisk = trend.total == 0
        ? 60 // Unknown, not perfect — do not award a clean bill of health.
        : ((1.0 - trend.threatRatio) * 100).round().clamp(0, 100);

    // Link exposure: penalise the share of messages carrying links that were
    // flagged, so one phishing link in one message does not dominate.
    final withLinks = reports
        .where((r) => r.analysis.ruleAnalysis.detectedUrls.isNotEmpty)
        .toList();

    final linkExposure = withLinks.isEmpty
        ? 100
        : ((1.0 -
                      (withLinks.where((r) => r.analysis.isThreat).length /
                          withLinks.length)) *
                  100)
              .round()
              .clamp(0, 100);

    // Account hygiene: driven by how many high-risk messages suggest credential
    // theft, plus whether the user is engaging with the feedback loop.
    final credentialPressure = trend.byType.keys
        .where((t) => t.name == 'phishing' || t.name == 'socialEngineering')
        .fold<int>(0, (sum, t) => sum + (trend.byType[t] ?? 0));

    final accountHygiene = trend.total == 0
        ? 70
        : (100 - ((credentialPressure / trend.total) * 120).round()).clamp(
            10,
            100,
          );

    return CompoundSecurityScore(
      messageRisk: messageRisk,
      linkExposure: linkExposure,
      accountHygiene: accountHygiene,
      devicePosture: posture.score,
      trend: trend,
      posture: posture,
    );
  }
}

enum ScoreGrade { excellent, good, fair, weak, critical }

enum ScoreContributor { messages, links, accounts, device }
