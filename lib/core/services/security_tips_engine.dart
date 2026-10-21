import '../models/threat_analysis.dart';
import 'threat_engine.dart';
import 'threat_trend.dart';

/// A recommendation derived from the user's own observed data.
class SecurityTip {
  final String id;

  /// Why this tip is being shown — cites the user's own numbers.
  final String observation;

  /// What to do about it.
  final String action;

  /// 0..100, used to order the list.
  final int priority;

  final TipCategory category;

  const SecurityTip({
    required this.id,
    required this.observation,
    required this.action,
    required this.priority,
    required this.category,
  });
}

enum TipCategory { messages, links, accounts, device }

/// Generates personalised security advice.
///
/// The difference between this and a static "security tips" list is that every
/// tip is justified by something the app actually observed, stated in the tip
/// itself ("you received 12 delivery-scam messages"). Generic advice gets
/// ignored; advice that names your own data gets acted on.
class SecurityTipsEngine {
  const SecurityTipsEngine();

  List<SecurityTip> generate({
    required List<MessageThreatReport> reports,
    required int feedbackCount,
    required int mutedSenderCount,
    required bool hasSmsPermission,
  }) {
    final tips = <SecurityTip>[];

    if (reports.isEmpty) {
      tips.add(
        const SecurityTip(
          id: 'start_scan',
          observation: 'Nothing has been scanned yet on this device.',
          action:
              'Grant SMS access (or share messages to ThreatGuard from the app '
              'they arrived in) so threats can be flagged before you tap.',
          priority: 95,
          category: TipCategory.messages,
        ),
      );
    }

    final trend = ThreatTrend.fromReports(reports);

    // ------------------------------------------------- delivery-scam cohort
    final deliveryScams = reports
        .where(
          (r) =>
              r.analysis.isThreat &&
              _mentionsAny(r.message.body, const [
                'parcel',
                'package',
                'delivery',
                'shipment',
                'courier',
                'customs',
              ]),
        )
        .length;

    if (deliveryScams >= 2) {
      tips.add(
        SecurityTip(
          id: 'delivery_cluster',
          observation:
              'You have received $deliveryScams messages about parcels or '
              'deliveries that ThreatGuard flagged.',
          action:
              'This is the most common scam run in this country. Never pay a '
              '"release fee" through a link — track parcels only in the '
              'courier\'s own app.',
          priority: 85,
          category: TipCategory.messages,
        ),
      );
    }

    // -------------------------------------------------- credential requests
    final credentialRequests = reports
        .where((r) => r.analysis.isThreat && _isPhishing(r.analysis.finalType))
        .length;

    if (credentialRequests >= 2) {
      tips.add(
        SecurityTip(
          id: 'phishing_cluster',
          observation:
              '$credentialRequests messages tried to get you to verify '
              'account details or enter a password.',
          action:
              'Your number is on a phishing list. Turn on two-factor '
              'authentication for your bank and e-mail, and use an '
              'authenticator app rather than SMS codes where possible.',
          priority: 90,
          category: TipCategory.accounts,
        ),
      );
    }

    // -------------------------------------------------------- link exposure
    final riskyLinks = reports
        .where((r) => r.analysis.ruleAnalysis.detectedUrls.isNotEmpty)
        .length;

    if (riskyLinks >= 5) {
      tips.add(
        SecurityTip(
          id: 'link_volume',
          observation: '$riskyLinks of your scanned messages contained links.',
          action:
              'Get into the habit of running unfamiliar links through the Link '
              'scanner before opening them — it shows the real destination '
              'domain.',
          priority: 60,
          category: TipCategory.links,
        ),
      );
    }

    // ------------------------------------------------- repeated high risk
    if (trend.highRisk >= 3) {
      tips.add(
        SecurityTip(
          id: 'high_risk_volume',
          observation:
              '${trend.highRisk} of your messages are high risk — '
              '${(trend.threatRatio * 100).toStringAsFixed(0)}% of everything '
              'scanned.',
          action:
              'Consider turning on Strict mode, and mute the senders behind '
              'these messages so real threats stand out.',
          priority: 80,
          category: TipCategory.messages,
        ),
      );
    }

    // ------------------------------------------------------ campaign signal
    final campaigns = reports
        .where((r) => r.templateMatch?.isCampaign ?? false)
        .length;

    if (campaigns >= 2) {
      tips.add(
        SecurityTip(
          id: 'campaign_detected',
          observation:
              '$campaigns of your messages are near-duplicates of the same '
              'campaign template.',
          action:
              'You are on a mass-mailing list. Do not reply — replying '
              'confirms your number is active. Block the sender instead.',
          priority: 75,
          category: TipCategory.messages,
        ),
      );
    }

    // --------------------------------------------------------- engagement
    if (reports.isNotEmpty && feedbackCount == 0) {
      tips.add(
        const SecurityTip(
          id: 'no_feedback',
          observation: 'You have not rated any verdict yet.',
          action:
              'Confirming or correcting verdicts with the feedback buttons '
              'builds a labelled dataset you can export, and is the fastest '
              'way to improve detection for your own messages.',
          priority: 45,
          category: TipCategory.messages,
        ),
      );
    }

    if (mutedSenderCount == 0 && trend.threatCount >= 3) {
      tips.add(
        const SecurityTip(
          id: 'no_mutes',
          observation: 'No senders are muted, but you have repeat threats.',
          action:
              'Long-press a threat message to mute its sender. Cutting the '
              'noise makes the messages that matter much easier to spot.',
          priority: 40,
          category: TipCategory.messages,
        ),
      );
    }

    if (!hasSmsPermission) {
      tips.add(
        const SecurityTip(
          id: 'no_sms_access',
          observation: 'ThreatGuard does not have SMS access on this device.',
          action:
              'ThreatGuard can still check anything you paste or share to it, '
              'but automatic scanning needs SMS access.',
          priority: 70,
          category: TipCategory.device,
        ),
      );
    }

    // ------------------------------------------------- always-on fundamentals
    tips.add(
      const SecurityTip(
        id: 'reuse_fundamental',
        observation: 'Password reuse is the most exploited weakness there is.',
        action:
            'Give every account a different password and keep them in a '
            'password manager. Check your main address in Breach check to see '
            'what is already circulating.',
        priority: 50,
        category: TipCategory.accounts,
      ),
    );

    tips.add(
      const SecurityTip(
        id: 'screen_lock_fundamental',
        observation:
            'A stolen unlocked phone gives an attacker your e-mail, your bank '
            'and every second factor.',
        action:
            'Set a 6-digit PIN or longer and enable biometrics, and set your '
            'screen to lock quickly.',
        priority: 35,
        category: TipCategory.device,
      ),
    );

    tips.sort((a, b) => b.priority.compareTo(a.priority));
    return tips;
  }

  static bool _isPhishing(ThreatType type) =>
      type == ThreatType.phishing || type == ThreatType.socialEngineering;

  static bool _mentionsAny(String text, List<String> needles) {
    final lower = text.toLowerCase();
    return needles.any(lower.contains);
  }
}
