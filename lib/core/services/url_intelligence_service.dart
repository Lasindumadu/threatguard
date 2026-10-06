import '../models/url_intelligence.dart';
import 'url_analyzer.dart';
import 'url_reputation_provider.dart';

class UrlIntelligenceService {
  final UrlAnalyzer urlAnalyzer;
  final UrlReputationProvider reputationProvider;

  const UrlIntelligenceService({
    this.urlAnalyzer = const UrlAnalyzer(),
    required this.reputationProvider,
  });

  Future<UrlIntelligence> analyze(String url) async {
    final structuralAnalysis = urlAnalyzer.analyze(url);
    final reputation = await reputationProvider.checkUrl(url);

    return UrlIntelligence(
      url: url,
      structuralAnalysis: structuralAnalysis,
      reputation: reputation,
    );
  }
}
