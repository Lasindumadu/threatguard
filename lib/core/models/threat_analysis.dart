enum ThreatLevel { safe, suspicious, highRisk }

enum ThreatType { legitimate, spam, phishing, scam, socialEngineering }

class ThreatIndicator {
  final String title;
  final String description;
  final int scoreContribution;

  const ThreatIndicator({
    required this.title,
    required this.description,
    required this.scoreContribution,
  });
}

class ThreatAnalysis {
  final int riskScore;
  final ThreatLevel level;
  final ThreatType type;
  final List<ThreatIndicator> indicators;
  final List<String> detectedUrls;
  final String summary;
  final String recommendation;

  const ThreatAnalysis({
    required this.riskScore,
    required this.level,
    required this.type,
    required this.indicators,
    required this.detectedUrls,
    required this.summary,
    required this.recommendation,
  });
}
