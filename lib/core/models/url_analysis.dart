enum UrlSignalType {
  ipAddressHost,
  punycodeHost,
  mixedScriptHost,
  embeddedCredentials,
  nonStandardPort,
  excessiveSubdomains,
  urlShortener,
}

class UrlSignal {
  final UrlSignalType type;
  final String title;
  final String description;

  const UrlSignal({
    required this.type,
    required this.title,
    required this.description,
  });
}

class UrlAnalysis {
  final String url;
  final String host;
  final String? domain;
  final List<UrlSignal> signals;

  const UrlAnalysis({
    required this.url,
    required this.host,
    required this.domain,
    required this.signals,
  });
}
