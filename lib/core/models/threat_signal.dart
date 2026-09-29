enum ThreatSignalCategory {
  urgency,
  accountSecurity,
  credential,
  financial,
  prizeReward,
  secrecy,
  authority,
  promotion,
  url,
}

enum ThreatSignalStrength { weak, moderate, strong }

class ThreatSignal {
  final String id;
  final String ruleId;
  final ThreatSignalCategory category;
  final ThreatSignalStrength strength;
  final String title;
  final String description;
  final String evidence;

  const ThreatSignal({
    required this.id,
    required this.ruleId,
    required this.category,
    required this.strength,
    required this.title,
    required this.description,
    required this.evidence,
  });
}
