enum UrlReputationStatus {
  unknown,
  valid,
  invalid,
  safe,
  suspicious,
  malicious,
}

enum UrlReputationSource { local, online, composite, unknown }

class UrlReputation {
  final String url;
  final UrlReputationStatus status;
  final String? reason;
  final UrlReputationSource source;
  final double? confidence;
  final DateTime? checkedAt;

  const UrlReputation({
    required this.url,
    required this.status,
    this.reason,
    this.source = UrlReputationSource.unknown,
    this.confidence,
    this.checkedAt,
  });
}
