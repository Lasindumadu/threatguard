import '../models/ml_feature_vector.dart';
import '../models/url_analysis.dart';
import 'signal_features.dart';
import 'text_matcher.dart';
import 'text_preprocessor.dart';
import 'url_analyzer.dart';
import 'url_extractor.dart';

/// Turns a message into the boolean/integer vector the classifier consumes.
///
/// Every signal here comes from the same [SignalFeatures] value and the same
/// [UrlExtractor] the rule engine uses. A feature can therefore never describe
/// a different message than the rules did — the previous implementation had
/// already drifted, missing `send otp` and `send pin` entirely.

class MlFeatureExtractor {
  final UrlAnalyzer urlAnalyzer;

  const MlFeatureExtractor({this.urlAnalyzer = const UrlAnalyzer()});

  /// Upper bound matching `ThreatAnalyzer.maxMessageLength`. Both defer to
  /// [TextPreprocessor.maxLength], so the rules and the model can never read
  /// different amounts of the same message.
  static const int maxMessageLength = TextPreprocessor.maxLength;

  /// Parcel vocabulary. Not a threat category — it separates "your parcel needs
  /// a fee" from a genuine delivery notice.
  static const List<String> _deliveryWords = [
    'delivery',
    'delivery service',
    'delivery company',
    'package',
    'parcel',
    'shipment',
    'courier',
    'shipping',
  ];

  MlFeatureVector extract({
    required String? message,
    String caseId = '',
    String? scenarioFamily,
  }) {
    final bounded = TextPreprocessor.capTokenLength(
      TextPreprocessor.bound(message, maxLength: maxMessageLength).text,
    );

    final urls = UrlExtractor.extract(bounded);
    final urlAnalyses = urlAnalyzer.analyzeAll(urls);

    // The same folded form the rule engine scans. It used to extract from the
    // raw text, so an obfuscated message looked different to the model and to
    // the rules — the exact drift this file was written to prevent.
    final scan = TextPreprocessor.matchingForm(bounded);
    final features = SignalFeatures.extract(scan);

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

    final hasCredentialRequest = features.hasCredentialRequest;

    final hasPrizeFinancialCombination =
        features.hasPrizePattern && features.hasFinancialRequest;

    final hasAccountCredentialCombination =
        (features.hasAccountThreat ||
            features.hasAccountVerificationLanguage) &&
        hasCredentialRequest;

    final hasAuthorityCredentialCombination =
        features.hasAuthorityReference && hasCredentialRequest;

    final hasUrgencyCredentialCombination =
        features.hasUrgency && hasCredentialRequest;

    return MlFeatureVector(
      caseId: caseId,
      scenarioFamily: scenarioFamily,
      // Length of the content the model actually saw.
      messageLength: bounded.replaceAll(' ', '').length,
      wordCount: _wordCount(bounded),
      urlCount: urls.length,
      hasUrgency: features.hasUrgency,
      hasAccountSecurity: features.hasAccountThreat,
      hasCredential: features.hasCredentialSignal,
      hasFinancial: features.hasFinancialRequest,
      hasPrizeReward: features.hasPrizePattern,
      hasSecrecy: features.hasSecrecyPressure,
      hasAuthority: features.hasAuthorityReference,
      hasPromotion: features.hasPromotionalLanguage,
      hasDeliveryContext: TextMatcher.containsAny(scan, _deliveryWords),
      hasUrl: hasUrl,
      hasSuspiciousUrl: hasSuspiciousUrl,
      hasIpUrl: hasIpUrl,
      hasPunycodeUrl: hasPunycodeUrl,
      hasEmbeddedCredentialsUrl: hasEmbeddedCredentialsUrl,
      hasNonStandardPortUrl: hasNonStandardPortUrl,
      hasExcessiveSubdomainsUrl: hasExcessiveSubdomainsUrl,
      hasShortenerUrl: hasShortenerUrl,
      hasAccountVerification: features.hasAccountVerificationLanguage,
      hasIdentityVerification: features.hasIdentityVerificationLanguage,
      hasCredentialRequest: hasCredentialRequest,
      hasStrongCredentialRequest: features.hasStrongCredentialRequest,
      hasPrizeFinancialCombination: hasPrizeFinancialCombination,
      hasAccountCredentialCombination: hasAccountCredentialCombination,
      hasAuthorityCredentialCombination: hasAuthorityCredentialCombination,
      hasUrgencyCredentialCombination: hasUrgencyCredentialCombination,
    );
  }

  bool _hasUrlSignal(List<UrlAnalysis> analyses, UrlSignalType type) {
    return analyses.any(
      (analysis) => analysis.signals.any((signal) => signal.type == type),
    );
  }

  int _wordCount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }}
