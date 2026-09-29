import '../models/ml_feature_vector.dart';
import '../models/threat_signal.dart';
import '../models/url_analysis.dart';
import 'threat_rule_catalog.dart';
import 'url_analyzer.dart';

class MlFeatureExtractor {
  final UrlAnalyzer urlAnalyzer;

  const MlFeatureExtractor({this.urlAnalyzer = const UrlAnalyzer()});

  MlFeatureVector extract({required String message, String caseId = ''}) {
    final text = message.trim().toLowerCase();

    final urls = _extractUrls(text);
    final urlAnalyses = urlAnalyzer.analyzeAll(urls);

    final hasUrgency = _hasCategory(text, ThreatSignalCategory.urgency);

    final hasAccountSecurity = _hasCategory(
      text,
      ThreatSignalCategory.accountSecurity,
    );

    final hasCredential = _hasCategory(text, ThreatSignalCategory.credential);

    final hasFinancial = _hasCategory(text, ThreatSignalCategory.financial);

    final hasPrizeReward = _hasCategory(text, ThreatSignalCategory.prizeReward);

    final hasSecrecy = _hasCategory(text, ThreatSignalCategory.secrecy);

    final hasAuthority = _hasCategory(text, ThreatSignalCategory.authority);

    final hasPromotion = _hasCategory(text, ThreatSignalCategory.promotion);

    final hasUrl = urls.isNotEmpty;

    final hasIpUrl = _hasUrlSignal(urlAnalyses, UrlSignalType.ipAddressHost);

    final hasPunycodeUrl = _hasUrlSignal(
      urlAnalyses,
      UrlSignalType.punycodeHost,
    );

    final hasEmbeddedCredentialsUrl = _hasUrlSignal(
      urlAnalyses,
      UrlSignalType.embeddedCredentials,
    );

    final hasNonStandardPortUrl = _hasUrlSignal(
      urlAnalyses,
      UrlSignalType.nonStandardPort,
    );

    final hasExcessiveSubdomainsUrl = _hasUrlSignal(
      urlAnalyses,
      UrlSignalType.excessiveSubdomains,
    );

    final hasShortenerUrl = _hasUrlSignal(
      urlAnalyses,
      UrlSignalType.urlShortener,
    );

    final hasSuspiciousUrl =
        hasIpUrl ||
        hasPunycodeUrl ||
        hasEmbeddedCredentialsUrl ||
        hasNonStandardPortUrl ||
        hasExcessiveSubdomainsUrl ||
        hasShortenerUrl;

    final hasDeliveryContext = _containsAny(text, [
      'delivery',
      'delivery service',
      'delivery company',
      'package',
      'parcel',
      'shipment',
      'courier',
      'shipping',
    ]);

    final hasAccountVerification = _containsAny(text, [
      'verify your account',
      'verify account',
      'account verification',
      'confirm your account',
      'confirm account',
      'confirm your account details',
      'security verification',
    ]);

    final hasIdentityVerification = _containsAny(text, [
      'verify your identity',
      'confirm your identity',
      'identity verification',
    ]);

    final hasCredentialRequest = _containsAny(text, [
      'send your password',
      'provide your password',
      'enter your password',
      'share your password',
      'submit your password',
      'confirm your password',
      'need your password',
      'needs your password',
      'require your password',
      'requires your password',
      'send your otp',
      'provide your otp',
      'enter your otp',
      'share your otp',
      'submit your otp',
      'confirm your otp',
      'need your otp',
      'needs your otp',
      'require your otp',
      'requires your otp',
      'send your verification code',
      'provide your verification code',
      'enter your verification code',
      'share your verification code',
      'submit your verification code',
      'confirm your verification code',
      'need your verification code',
      'needs your verification code',
      'require your verification code',
      'requires your verification code',
      'send your security code',
      'provide your security code',
      'enter your security code',
      'share your security code',
      'submit your security code',
      'confirm your security code',
      'need your security code',
      'needs your security code',
      'require your security code',
      'requires your security code',
      'send your pin',
      'provide your pin',
      'enter your pin',
      'share your pin',
      'submit your pin',
      'confirm your pin',
      'need your pin',
      'needs your pin',
      'require your pin',
      'requires your pin',
    ]);

    final hasStrongCredentialRequest = _containsAny(text, [
      'send your otp',
      'provide your otp',
      'enter your otp',
      'share your otp',
      'submit your otp',
      'confirm your otp',
      'need your otp',
      'needs your otp',
      'require your otp',
      'requires your otp',
      'send your verification code',
      'provide your verification code',
      'enter your verification code',
      'share your verification code',
      'submit your verification code',
      'confirm your verification code',
      'need your verification code',
      'needs your verification code',
      'require your verification code',
      'requires your verification code',
      'send your security code',
      'provide your security code',
      'enter your security code',
      'share your security code',
      'submit your security code',
      'confirm your security code',
      'need your security code',
      'needs your security code',
      'require your security code',
      'requires your security code',
    ]);

    final hasPrizeFinancialCombination = hasPrizeReward && hasFinancial;

    final hasAccountCredentialCombination =
        (hasAccountSecurity || hasAccountVerification) && hasCredentialRequest;

    final hasAuthorityCredentialCombination =
        hasAuthority && hasCredentialRequest;

    final hasUrgencyCredentialCombination = hasUrgency && hasCredentialRequest;

    return MlFeatureVector(
      caseId: caseId,
      messageLength: text.length,
      wordCount: _wordCount(text),
      urlCount: urls.length,
      hasUrgency: hasUrgency,
      hasAccountSecurity: hasAccountSecurity,
      hasCredential: hasCredential,
      hasFinancial: hasFinancial,
      hasPrizeReward: hasPrizeReward,
      hasSecrecy: hasSecrecy,
      hasAuthority: hasAuthority,
      hasPromotion: hasPromotion,
      hasDeliveryContext: hasDeliveryContext,
      hasUrl: hasUrl,
      hasSuspiciousUrl: hasSuspiciousUrl,
      hasIpUrl: hasIpUrl,
      hasPunycodeUrl: hasPunycodeUrl,
      hasEmbeddedCredentialsUrl: hasEmbeddedCredentialsUrl,
      hasNonStandardPortUrl: hasNonStandardPortUrl,
      hasExcessiveSubdomainsUrl: hasExcessiveSubdomainsUrl,
      hasShortenerUrl: hasShortenerUrl,
      hasAccountVerification: hasAccountVerification,
      hasIdentityVerification: hasIdentityVerification,
      hasCredentialRequest: hasCredentialRequest,
      hasStrongCredentialRequest: hasStrongCredentialRequest,
      hasPrizeFinancialCombination: hasPrizeFinancialCombination,
      hasAccountCredentialCombination: hasAccountCredentialCombination,
      hasAuthorityCredentialCombination: hasAuthorityCredentialCombination,
      hasUrgencyCredentialCombination: hasUrgencyCredentialCombination,
    );
  }

  bool _hasCategory(String text, ThreatSignalCategory category) {
    return ThreatRuleCatalog.rules
        .where((rule) => rule.category == category)
        .any((rule) => rule.patterns.any(text.contains));
  }

  bool _hasUrlSignal(List<UrlAnalysis> analyses, UrlSignalType type) {
    return analyses.any(
      (analysis) => analysis.signals.any((signal) => signal.type == type),
    );
  }

  bool _containsAny(String text, List<String> patterns) {
    return patterns.any(text.contains);
  }

  int _wordCount(String text) {
    if (text.isEmpty) {
      return 0;
    }

    return text.split(RegExp(r'\s+')).length;
  }

  List<String> _extractUrls(String text) {
    final urlPattern = RegExp(r'(https?://|www\.)[^\s]+', caseSensitive: false);

    return urlPattern
        .allMatches(text)
        .map((match) => match.group(0)!)
        .map(_cleanUrl)
        .toList();
  }

  String _cleanUrl(String url) {
    return url.replaceAll(RegExp(r'[.,!?;:]+$'), '');
  }
}
