import 'url_analysis.dart';
import 'url_reputation.dart';

class UrlIntelligence {
  final String url;
  final UrlAnalysis structuralAnalysis;
  final UrlReputation reputation;

  const UrlIntelligence({
    required this.url,
    required this.structuralAnalysis,
    required this.reputation,
  });
}
