import '../models/threat_analysis.dart';
import '../models/threat_signal.dart';
import '../models/url_analysis.dart';
import 'threat_rule_catalog.dart';
import 'url_analyzer.dart';

class ThreatAnalyzer {
  final UrlAnalyzer urlAnalyzer;

  const ThreatAnalyzer({this.urlAnalyzer = const UrlAnalyzer()});

  ThreatAnalysis analyze(String message) {
    final text = message.trim().toLowerCase();

    if (text.isEmpty) {
      return const ThreatAnalysis(
        riskScore: 0,
        level: ThreatLevel.safe,
        type: ThreatType.legitimate,
        indicators: [],
        detectedUrls: [],
        summary: 'No message was provided.',
        recommendation: 'Enter a message to analyze.',
      );
    }

    final indicators = <ThreatIndicator>[];
    final detectedUrls = _extractUrls(text);
    final urlAnalyses = urlAnalyzer.analyzeAll(detectedUrls);

    final baseSignals = _collectBaseSignals(text);

    _applySignalIndicators(baseSignals, indicators);

    _applyUrlSignal(detectedUrls, indicators);

    _applyUrlStructuralIndicators(urlAnalyses, indicators);

    final context = _buildContext(text, baseSignals, detectedUrls, urlAnalyses);

    _applyContextSignals(context: context, indicators: indicators);

    final score = _calculateRiskScore(indicators: indicators, context: context);

    final level = _calculateLevel(score: score, context: context);

    final type = _classifyThreat(context: context, score: score);

    return ThreatAnalysis(
      riskScore: score,
      level: level,
      type: type,
      indicators: List.unmodifiable(indicators),
      detectedUrls: List.unmodifiable(detectedUrls),
      summary: _createSummary(type, level),
      recommendation: _createRecommendation(type, level),
    );
  }

  List<ThreatSignal> _collectBaseSignals(String text) {
    final signals = <ThreatSignal>[];

    for (final rule in ThreatRuleCatalog.rules) {
      String? matchedPattern;

      for (final pattern in rule.patterns) {
        if (text.contains(pattern)) {
          matchedPattern = pattern;
          break;
        }
      }

      if (matchedPattern == null) {
        continue;
      }

      signals.add(
        ThreatSignal(
          id: rule.id,
          ruleId: rule.id,
          category: rule.category,
          strength: rule.strength,
          title: rule.title,
          description: rule.description,
          evidence: matchedPattern,
        ),
      );
    }

    return signals;
  }

  void _applySignalIndicators(
    List<ThreatSignal> signals,
    List<ThreatIndicator> indicators,
  ) {
    for (final signal in signals) {
      var scoreContribution = 0;

      for (final rule in ThreatRuleCatalog.rules) {
        if (rule.id == signal.ruleId) {
          scoreContribution = rule.scoreContribution;
          break;
        }
      }

      indicators.add(
        ThreatIndicator(
          title: signal.title,
          description:
              '${signal.description} Detected evidence: "${signal.evidence}".',
          scoreContribution: scoreContribution,
        ),
      );
    }
  }

  void _applyUrlSignal(List<String> urls, List<ThreatIndicator> indicators) {
    if (urls.isEmpty) {
      return;
    }

    indicators.add(
      const ThreatIndicator(
        title: 'External URL detected',
        description: 'The message contains a web link that may require additional analysis.',
        scoreContribution: 8,
      ),
    );
  }

  void _applyUrlStructuralIndicators(
    List<UrlAnalysis> analyses,
    List<ThreatIndicator> indicators,
  ) {
    for (final analysis in analyses) {
      for (final signal in analysis.signals) {
        indicators.add(
          ThreatIndicator(
            title: signal.title,
            description:
                '${signal.description} Detected in: "${analysis.url}".',
            scoreContribution: 0,
          ),
        );
      }
    }
  }

  void _applyContextSignals({
    required _ThreatContext context,
    required List<ThreatIndicator> indicators,
  }) {
    if (context.hasCredentialRequest) {
      indicators.add(
        const ThreatIndicator(
          title: 'Credential collection request',
          description: 'The message appears to request sensitive authentication information rather than merely mentioning it.',
          scoreContribution: 0,
        ),
      );
    }

    if (context.hasCredentialRequest && context.hasAccountThreat) {
      indicators.add(
        const ThreatIndicator(
          title: 'Account threat combined with credential request',
          description: 'An account or security warning is combined with a request involving authentication information.',
          scoreContribution: 0,
        ),
      );
    }

    if (context.hasUrgency && context.hasCredentialRequest) {
      indicators.add(
        const ThreatIndicator(
          title: 'Urgency combined with credential request',
          description: 'Time pressure is combined with a request for authentication information.',
          scoreContribution: 0,
        ),
      );
    }

    if (context.hasPrizePattern && context.hasFinancialRequest) {
      indicators.add(
        const ThreatIndicator(
          title: 'Prize and financial request combination',
          description: 'An unexpected reward or prize is combined with a request involving money or financial information.',
          scoreContribution: 0,
        ),
      );
    }

    if (context.hasPrizePattern && context.hasUrgency) {
      indicators.add(
        const ThreatIndicator(
          title: 'Prize and urgency combination',
          description:
              'An unexpected reward is combined with pressure to act quickly.',
          scoreContribution: 0,
        ),
      );
    }

    if (context.hasAuthorityReference &&
        context.hasSecrecyPressure &&
        context.hasUrgency &&
        context.hasCredentialRequest) {
      indicators.add(
        const ThreatIndicator(
          title: 'High-pressure authority manipulation pattern',
          description: 'Authority-related language is combined with secrecy, urgency, and a credential request.',
          scoreContribution: 0,
        ),
      );
    }

    if (context.hasAuthorityReference &&
        context.hasSecrecyPressure &&
        context.hasUrgency &&
        context.hasFinancialRequest) {
      indicators.add(
        const ThreatIndicator(
          title: 'High-pressure financial manipulation pattern',
          description: 'Authority-related language is combined with secrecy, urgency, and financial information or payment language.',
          scoreContribution: 0,
        ),
      );
    }
  }

  int _calculateRiskScore({
    required List<ThreatIndicator> indicators,
    required _ThreatContext context,
  }) {
    var score = indicators.fold<int>(
      0,
      (total, indicator) => total + indicator.scoreContribution,
    );

    /*
     * Contextual combinations influence the score only when they
     * represent a meaningful escalation. They do not receive another
     * independent score through ThreatIndicator.
     */

    if (context.hasCredentialRequest && context.hasAccountThreat) {
      score += 8;
    }

    if (context.hasCredentialRequest && context.hasUrgency) {
      score += 5;
    }

    if (context.hasPrizePattern && context.hasFinancialRequest) {
      score += 8;
    }

    if (context.hasPrizePattern && context.hasUrgency) {
      score += 4;
    }

    if (context.hasAuthorityReference &&
        context.hasSecrecyPressure &&
        context.hasUrgency &&
        context.hasCredentialRequest) {
      score += 10;
    }

    if (context.hasAuthorityReference &&
        context.hasSecrecyPressure &&
        context.hasUrgency &&
        context.hasFinancialRequest) {
      score += 8;
    }

    return score.clamp(0, 100);
  }

  ThreatLevel _calculateLevel({
    required int score,
    required _ThreatContext context,
  }) {
    // Strong phishing/social-engineering combinations.
    if (context.hasCredentialRequestContext &&
        (context.hasUrgency || context.hasAccountThreat) &&
        (context.hasStrongCredentialRequest ||
            !context.hasAuthorityReference ||
            context.hasIdentityVerificationLanguage)) {
      return ThreatLevel.highRisk;
    }

    // Explicit account-lock / identity-verification phishing without
    // an external URL.
    if (context.hasAccountThreat &&
        context.hasIdentityVerificationLanguage &&
        !context.hasUrl) {
      return ThreatLevel.highRisk;
    }

    // Account/security phishing combined with a structurally suspicious URL.
    if (context.hasAccountThreatWithSuspiciousUrl) {
      return ThreatLevel.highRisk;
    }

    // Security/account verification combined with a credential request.
    // Identity-verification wording alone is not enough.
    if (context.hasCredentialRequestContext &&
        !context.hasIdentityVerificationLanguage &&
        (!context.hasAuthorityReference ||
            context.hasStrongCredentialRequest ||
            context.hasUrl)) {
      return ThreatLevel.highRisk;
    }

    // Strong OTP/verification-code social engineering:
    // authority + urgency + credential request.
    //
    // Delivery-company/support-style requests remain suspicious unless
    // they contain stronger account/security context.
    if (context.hasBankSecurityReference &&
        context.hasUrgency &&
        context.hasCredentialRequest) {
      return ThreatLevel.highRisk;
    }

    final hasStrongPhishingCombination =
        context.hasCredentialRequest &&
        (context.hasAccountThreat || context.hasUrl) &&
        (!context.hasAuthorityReference ||
            context.hasStrongCredentialRequest ||
            context.hasIdentityVerificationLanguage);

    final hasStrongSocialEngineeringCombination =
        context.hasAuthorityReference &&
        context.hasSecrecyPressure &&
        context.hasUrgency &&
        (context.hasStrongCredentialRequest || context.hasFinancialRequest);

    if (hasStrongPhishingCombination || hasStrongSocialEngineeringCombination) {
      return ThreatLevel.highRisk;
    }

    // A simple account-information verification request through an
    // organization/service desk should not become suspicious solely
    // because its additive score crosses 25.
    if (context.hasAccountThreat &&
        context.hasAuthorityReference &&
        !context.hasUrgency &&
        !context.hasCredentialRequest &&
        !context.hasFinancialRequest &&
        !context.hasPrizePattern &&
        !context.hasUrl) {
      return ThreatLevel.safe;
    }

    if (score >= 25 ||
        context.hasCredentialRequest ||
        context.hasPrizePattern ||
        context.hasFinancialRequest) {
      return ThreatLevel.suspicious;
    }

    if (context.hasPromotionalLanguage) {
      return ThreatLevel.suspicious;
    }

    return ThreatLevel.safe;
  }

  ThreatType _classifyThreat({
    required _ThreatContext context,
    required int score,
  }) {
    /*
     * Specific contextual patterns are evaluated before broader
     * categories. This prevents credential-related language from
     * automatically turning authority-based social-engineering messages
     * into phishing.
     */

    if (context.hasAccountVerificationUrlPattern ||
        (context.hasAccountThreat && context.hasIdentityVerificationLanguage)) {
      return ThreatType.phishing;
    }

    if (context.hasAuthorityReference &&
        (context.hasUrgency || context.hasSecrecyPressure) &&
        (context.hasCredentialRequest || context.hasFinancialRequest)) {
      return ThreatType.socialEngineering;
    }

    if (context.hasAuthorityReference &&
        context.hasSecrecyPressure &&
        context.hasUrgency) {
      return ThreatType.socialEngineering;
    }

    if (context.hasCredentialRequest) {
      return ThreatType.phishing;
    }

    if (context.hasCredentialSignal &&
        (context.hasAccountThreat || context.hasUrl)) {
      return ThreatType.phishing;
    }

    if (context.hasPrizePattern && context.hasUrl) {
      return ThreatType.scam;
    }

    if (context.hasPrizePattern && context.hasFinancialRequest) {
      return ThreatType.scam;
    }

    if (context.hasPrizePattern &&
        context.hasUrgency &&
        !context.hasPromotionalLanguage) {
      return ThreatType.scam;
    }

    if (context.hasFinancialRequest &&
        !context.hasAuthorityReference &&
        !context.hasPromotionalLanguage) {
      return ThreatType.scam;
    }

    if (context.hasPromotionalLanguage) {
      return ThreatType.spam;
    }

    final hasGenericSuspiciousActivity =
        context.hasUrgency ||
        context.hasCredentialRequest ||
        context.hasFinancialRequest ||
        context.hasPrizePattern ||
        context.hasUrl;

    if (score >= 25 && hasGenericSuspiciousActivity) {
      return ThreatType.spam;
    }

    return ThreatType.legitimate;
  }

  bool _hasSignalCategory(
    List<ThreatSignal> signals,
    ThreatSignalCategory category,
  ) {
    return signals.any((signal) => signal.category == category);
  }

  _ThreatContext _buildContext(
    String text,
    List<ThreatSignal> signals,
    List<String> detectedUrls,
    List<UrlAnalysis> urlAnalyses,
  ) {
    final hasBankSecurityReference = _containsAny(text, [
      'bank security',
      'bank security department',
      'bank security team',
      'bank security officer',
    ]);
    final hasCredentialSignal = _hasSignalCategory(
      signals,
      ThreatSignalCategory.credential,
    );

    final hasAccountThreat = _hasSignalCategory(
      signals,
      ThreatSignalCategory.accountSecurity,
    );

    final hasUrgency = _hasSignalCategory(
      signals,
      ThreatSignalCategory.urgency,
    );

    final hasPrizePattern = _hasSignalCategory(
      signals,
      ThreatSignalCategory.prizeReward,
    );

    final hasFinancialRequest = _hasSignalCategory(
      signals,
      ThreatSignalCategory.financial,
    );

    final hasAuthorityReference = _hasSignalCategory(
      signals,
      ThreatSignalCategory.authority,
    );

    final hasSecrecyPressure = _hasSignalCategory(
      signals,
      ThreatSignalCategory.secrecy,
    );

    final hasUrl = detectedUrls.isNotEmpty;

    final hasPromotionalLanguage = _hasSignalCategory(
      signals,
      ThreatSignalCategory.promotion,
    );

    final hasCredentialRequest = _containsAny(text, [
      'send your password',
      'provide your password',
      'enter your password',
      'share your password',
      'submit your password',
      'confirm your password',
      'verify your password',
      'need your password',
      'needs your password',
      'require your password',
      'requires your password',
      'send password',
      'provide password',
      'enter password',
      'share password',
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
      'send otp',
      'provide otp',
      'enter otp',
      'share otp',
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
      'send verification code',
      'provide verification code',
      'enter verification code',
      'share verification code',
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
      'send security code',
      'provide security code',
      'enter security code',
      'share security code',
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
      'send pin',
      'provide pin',
      'enter pin',
      'share pin',
      'enter your login details',
      'provide your login details',
      'confirm your login details',
      'submit your login details',
      'enter login details',
      'provide login details',
      'confirm login details',
      'submit login details',
      'entering your pin',
      'entering pin',
      'entering your security code',
      'entering security code',
      'entering your verification code',
      'entering verification code',
      'entering your otp',
      'entering otp',
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
      'send otp',
      'provide otp',
      'enter otp',
      'share otp',
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
      'send verification code',
      'provide verification code',
      'enter verification code',
      'share verification code',
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
      'send security code',
      'provide security code',
      'enter security code',
      'share security code',
    ]);

    final hasAccountVerificationLanguage = _containsAny(text, [
      'verify your account',
      'verify account',
      'account verification',
      'verify your identity',
      'confirm your account',
      'confirm account',
      'security verification',
    ]);

    final hasSuspiciousUrlStructure = urlAnalyses.any(
      (analysis) => analysis.signals.any(
        (signal) =>
            signal.type == UrlSignalType.punycodeHost ||
            signal.type == UrlSignalType.ipAddressHost ||
            signal.type == UrlSignalType.embeddedCredentials ||
            signal.type == UrlSignalType.nonStandardPort ||
            signal.type == UrlSignalType.excessiveSubdomains ||
            signal.type == UrlSignalType.urlShortener,
      ),
    );

    final hasIdentityVerificationLanguage = _containsAny(text, [
      'verify your identity',
      'confirm your identity',
      'identity verification',
    ]);

    final hasCredentialRequestContext =
        hasCredentialRequest &&
        (hasAccountVerificationLanguage ||
            hasIdentityVerificationLanguage ||
            hasAccountThreat);

    return _ThreatContext(
      hasAccountVerificationUrlPattern:
          hasAccountVerificationLanguage && hasUrgency && hasUrl,
      hasAccountThreatWithSuspiciousUrl:
          hasAccountThreat &&
          hasAccountVerificationLanguage &&
          hasSuspiciousUrlStructure,
      hasCredentialSignal: hasCredentialSignal,
      hasCredentialRequestContext: hasCredentialRequestContext,
      hasIdentityVerificationLanguage: hasIdentityVerificationLanguage,
      hasCredentialRequest: hasCredentialRequest,
      hasAccountThreat: hasAccountThreat,
      hasUrgency: hasUrgency,
      hasPrizePattern: hasPrizePattern,
      hasFinancialRequest: hasFinancialRequest,
      hasAuthorityReference: hasAuthorityReference,
      hasSecrecyPressure: hasSecrecyPressure,
      hasPromotionalLanguage: hasPromotionalLanguage,
      hasBankSecurityReference: hasBankSecurityReference,
      hasStrongCredentialRequest: hasStrongCredentialRequest,
      hasUrl: hasUrl,
    );
  }

  String _createSummary(ThreatType type, ThreatLevel level) {
    if (level == ThreatLevel.safe) {
      return 'No major threat indicators were detected.';
    }

    switch (type) {
      case ThreatType.phishing:
        return 'This message contains patterns commonly associated with phishing attempts.';
      case ThreatType.scam:
        return 'This message contains patterns commonly associated with scams or deceptive offers.';
      case ThreatType.socialEngineering:
        return 'This message contains multiple signals associated with social-engineering techniques.';
      case ThreatType.spam:
        return 'This message contains signals that may indicate unsolicited or suspicious communication.';
      case ThreatType.legitimate:
        return 'No major threat indicators were detected.';
    }
  }

  String _createRecommendation(ThreatType type, ThreatLevel level) {
    if (level == ThreatLevel.safe) {
      return 'No immediate action is required. The message appears low risk based on the detected signals.';
    }

    if (level == ThreatLevel.highRisk) {
      if (type == ThreatType.phishing) {
        return 'Do not interact with this message until it has been independently verified. Do not provide passwords, OTPs, PINs, or other sensitive information.';
      }

      if (type == ThreatType.scam) {
        return 'Do not send money or provide financial information. Independently verify the offer before taking any action.';
      }

      if (type == ThreatType.socialEngineering) {
        return 'Do not respond or share sensitive information until the request has been independently verified through a trusted channel.';
      }

      return 'Do not interact with this message until it has been independently verified.';
    }

    if (type == ThreatType.phishing) {
      return 'Do not click suspicious links or provide passwords, OTPs, PINs, or other sensitive information. Verify the sender through an official channel.';
    }

    if (type == ThreatType.scam) {
      return 'Do not send money or provide financial information. Independently verify the offer before taking action.';
    }

    if (type == ThreatType.socialEngineering) {
      return 'Slow down and independently verify the request before responding or sharing sensitive information.';
    }

    return 'Be cautious with this message. Avoid providing sensitive information or following instructions until the sender is independently verified.';
  }

  bool _containsAny(String text, List<String> patterns) {
    return patterns.any(text.contains);
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

class _ThreatContext {
  final bool hasCredentialSignal;
  final bool hasCredentialRequest;
  final bool hasStrongCredentialRequest;
  final bool hasAccountThreat;
  final bool hasUrgency;
  final bool hasPrizePattern;
  final bool hasFinancialRequest;
  final bool hasAuthorityReference;
  final bool hasSecrecyPressure;
  final bool hasUrl;
  final bool hasPromotionalLanguage;
  final bool hasAccountVerificationUrlPattern;
  final bool hasAccountThreatWithSuspiciousUrl;
  final bool hasCredentialRequestContext;
  final bool hasIdentityVerificationLanguage;
  final bool hasBankSecurityReference;

  const _ThreatContext({
    required this.hasCredentialSignal,
    required this.hasCredentialRequest,
    required this.hasStrongCredentialRequest,
    required this.hasAccountThreat,
    required this.hasUrgency,
    required this.hasPrizePattern,
    required this.hasFinancialRequest,
    required this.hasAuthorityReference,
    required this.hasSecrecyPressure,
    required this.hasUrl,
    required this.hasPromotionalLanguage,
    required this.hasAccountVerificationUrlPattern,
    required this.hasAccountThreatWithSuspiciousUrl,
    required this.hasCredentialRequestContext,
    required this.hasIdentityVerificationLanguage,
    required this.hasBankSecurityReference,
  });
}
