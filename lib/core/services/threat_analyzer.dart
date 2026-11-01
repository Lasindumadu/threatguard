import 'package:flutter/foundation.dart';

import '../models/protection_mode.dart';
import '../models/threat_analysis.dart';
import '../models/threat_signal.dart';
import '../models/url_analysis.dart';
import 'signal_features.dart';
import 'text_matcher.dart';
import 'text_preprocessor.dart';
import 'threat_rule_catalog.dart';
import 'url_analyzer.dart';
import 'url_extractor.dart';
import 'verdict_policy.dart';

/// The rule engine: catalogued manipulation patterns, URL structure and
/// contextual combinations, scored additively and mapped to one of three
/// levels.
///
/// Three properties are deliberate and load-bearing:
///
///  1. **Every fact is computed once.** Category signals, credential-request
///     forms and URL analysis come from [SignalFeatures] and [UrlExtractor],
///     shared with the ML feature extractor. The two engines cannot drift.
///  2. **Evidence is de-duplicated by reason, not by count.** A message that
///     says "password" four times produces one indicator, because repetition is
///     not additional evidence.
///  3. **A score is not a probability and a pattern is not proof.** The score is
///     an additive risk index, exposed as such; nothing here can produce a
///     "confirmed" threat, because a phrase match cannot establish intent.
class ThreatAnalyzer {
  final UrlAnalyzer urlAnalyzer;

  const ThreatAnalyzer({this.urlAnalyzer = const UrlAnalyzer()});

  /// Upper bound on the characters analysed per message.
  ///
  /// MMS and pasted forwards can be tens of kilobytes. Every rule is a regex
  /// over the text, so an unbounded input makes detection latency proportional
  /// to message size. Truncating is honest only if it is reported: see
  /// [ThreatAnalysis.wasTruncated]. The bound itself lives in
  /// [TextPreprocessor] so the model, the rule engine and the URL extractor
  /// all read the same characters.
  static const int maxMessageLength = TextPreprocessor.maxLength;

  ThreatAnalysis analyze(
    String? message, {
    ProtectionMode mode = ProtectionMode.balanced,
  }) {
    final bounded = TextPreprocessor.bound(message);
    final content = TextPreprocessor.capTokenLength(bounded.text);

    if (content.isEmpty) {
      return ThreatAnalysis(
        riskScore: 0,
        level: ThreatLevel.safe,
        type: ThreatType.legitimate,
        indicators: const [],
        detectedUrls: const [],
        summary: 'No message was provided.',
        recommendation: 'Enter a message to analyze.',
        mode: mode,
      );
    }

    final truncated = bounded.wasTruncated;
    final text = content;

    // Scan the fully folded form. Before Phase 1 the engine scanned the raw
    // text, so `v3rify y0ur p4ssword` and a fullwidth "ＶＥＲＩＦＹ" matched
    // nothing — the folding only ever happened inside TextMatcher, which was
    // used for a handful of phrase checks.
    final scan = TextPreprocessor.matchingForm(text);

    final features = SignalFeatures.extract(scan);

    final detectedUrls = UrlExtractor.extract(text);
    final urlAnalyses = urlAnalyzer.analyzeAll(detectedUrls);

    final context = _ThreatContext.build(
      mode: mode,
      features: features,
      hasUrl: detectedUrls.isNotEmpty,
      urlAnalyses: urlAnalyses,
      text: scan,
    );

    final indicators = _collectIndicators(
      text: text,
      features: features,
      detectedUrls: detectedUrls,
      urlAnalyses: urlAnalyses,
      context: context,
    );

    // Deduplicate *before* scoring: the score must be the sum of distinct
    // evidence, and the duplicate count is reported rather than hidden.
    final deduped = _dedupe(indicators);
    final duplicatesRemoved = indicators.length - deduped.length;
    final scoring = applyEvidenceRules(
      deduped,
      hasCredentialRequest: features.hasCredentialRequest,
      safetyAdvice: context.hasCredentialSignalInSafetyAdvice,
    );
    final score = _calculateRiskScore(scoring.indicators, context);

    // Category first, from the facts; then the level, from the category and
    // the user's sensitivity. Doing it the other way round allowed a level to
    // exist with no matching category ("suspicious / legitimate").
    final dialecticType = _classifyThreat(context, scan, features);
    final level = _calculateLevel(
      score: score,
      context: context,
      mode: mode,
      type: dialecticType,
      text: scan,
    );
    // A level of `safe` means nothing was found, so there is no category to
    // report. A *suspicious* level keeps its category: Strict's lower floor is
    // allowed to surface a weak signal, and `_calculateLevel` documents that
    // outcome (it reports the weak signal at the category the facts support).
    // Absence of phishing/account/payment evidence is not proof of innocence,
    // so the category is never rewritten to `legitimate` on that basis alone.
    final type = level == ThreatLevel.safe
        ? ThreatType.legitimate
        : dialecticType;

    return ThreatAnalysis(
      riskScore: score,
      level: level,
      type: type,
      indicators: List.unmodifiable(scoring.indicators),
      detectedUrls: List.unmodifiable(detectedUrls),
      summary: _createSummary(type, level),
      recommendation: _createRecommendation(type, level),
      evidenceDuplicatesRemoved: duplicatesRemoved,
      wasTruncated: truncated,
      mode: mode,
      supportingEvidence: VerdictPolicy.positiveSignals(text),
      rawRiskScore: score,
      scoredEvidence: _scoredEvidence(scoring.indicators),
    );
  }

  /// Applies the evidence-level adjustments that need the whole, deduped
  /// indicator list rather than one rule at a time.
  ///
  /// **A warning is not a request.** If a credential is mentioned only inside
  /// a message telling the reader *not* to share credentials, the credential
  /// indicator stops contributing points. It stays visible, alongside an
  /// explanation, because hiding evidence the user can see in their own message
  /// is worse than explaining why it was not scored.
  @visibleForTesting
  static ({List<ThreatIndicator> indicators}) applyEvidenceRules(
    List<ThreatIndicator> indicators, {
    required bool hasCredentialRequest,
    required bool safetyAdvice,
  }) {
    var adjusted = indicators;

    if (safetyAdvice) {
      final credentialAdjusted = <ThreatIndicator>[];

      for (final indicator in adjusted) {
        if (indicator.category != ThreatSignalCategory.credential ||
            indicator.scoreContribution == 0) {
          credentialAdjusted.add(indicator);
          continue;
        }

        // A message that also asks for the credential is a request, not a
        // warning; leave the evidence, and its points, intact.
        if (hasCredentialRequest) {
          credentialAdjusted.add(indicator);
          continue;
        }

        credentialAdjusted.add(
          ThreatIndicator(
            title: indicator.title,
            description:
                'A credential is mentioned, but the message tells the reader '
                'not to share it. Treated as a warning, not a request.',
            scoreContribution: 0,
            evidence: indicator.evidence,
            category: indicator.category,
            provenance: EvidenceProvenance.observed,
            dedupeKey: indicator.identity,
          ),
        );
      }

      adjusted = credentialAdjusted;

      final identities = adjusted.map((i) => i.identity).toSet();
      if (!identities.contains(_explanatoryIndicator.identity)) {
        adjusted = [...adjusted, _explanatoryIndicator];
      }
    }

    return (indicators: List.unmodifiable(adjusted));
  }

  static const ThreatIndicator _explanatoryIndicator = ThreatIndicator(
    title: 'Credential warning, not credential collection',
    description:
        'The message mentions a password, code or PIN only to tell the reader '
        'not to share it. That is a security warning, not a request.',
    scoreContribution: 0,
    provenance: EvidenceProvenance.inferred,
    dedupeKey: 'context:credential-warning',
  );

  // ------------------------------------------------------------ indicators

  List<ThreatIndicator> _collectIndicators({
    required String text,
    required SignalFeatures features,
    required List<String> detectedUrls,
    required List<UrlAnalysis> urlAnalyses,
    required _ThreatContext context,
  }) {
    final indicators = <ThreatIndicator>[];

    for (final rule in ThreatRuleCatalog.rules) {
      if (!features.matched(rule.id)) continue;

      indicators.add(
        ThreatIndicator(
          title: rule.title,
          description: rule.description,
          scoreContribution: rule.scoreContribution,
          // Quote the user's original characters: TextMatcher searches every
          // normalization of it, so an obfuscated spelling still matches and
          // the evidence still reads as the user wrote it.
          evidence: _matchedSpan(text, rule.patterns) ?? rule.patterns.first,
          category: rule.category,
          provenance: EvidenceProvenance.observed,
          dedupeKey: 'rule:${rule.id}',
        ),
      );
    }

    if (detectedUrls.isNotEmpty) {
      indicators.add(
        ThreatIndicator(
          title: 'External URL detected',
          description:
              'The message contains a web link that may require additional analysis.',
          scoreContribution: 8,
          evidence: detectedUrls.first,
          category: ThreatSignalCategory.url,
          provenance: EvidenceProvenance.observed,
          dedupeKey: 'url-detected',
        ),
      );
    }

    // Structural URL signals are evidence-only: they shape the level (via
    // _ThreatContext) but add no points of their own, so one odd link cannot
    // stack five separate numeric penalties.
    for (final analysis in urlAnalyses) {
      for (final signal in analysis.signals) {
        indicators.add(
          ThreatIndicator(
            title: signal.title,
            description:
                '${signal.description} Detected in: "${analysis.url}".',
            scoreContribution: 0,
            evidence: analysis.url,
            category: ThreatSignalCategory.url,
            provenance: EvidenceProvenance.inferred,
            dedupeKey: 'url:${analysis.url.toLowerCase()}:${signal.type.name}',
          ),
        );
      }
    }

    _addContextIndicators(context, indicators);

    return indicators;
  }

  static String? _matchedSpan(String text, List<String> patterns) {
    for (final pattern in patterns) {
      final span = TextMatcher.firstMatch(text, pattern);
      if (span != null) return span;
    }
    return patterns.first;
  }

  /// Contextual combinations are the strongest signal the rule engine has.
  ///
  /// Each is listed once, and the points for a combination are added once, by
  /// [_calculateRiskScore]. A combination only exists when the evidence it
  /// summarises is present, and its [ThreatIndicator.evidence] quotes the span
  /// that triggered it, so a scored reason is never an unsupported claim.
  void _addContextIndicators(
    _ThreatContext context,
    List<ThreatIndicator> indicators,
  ) {
    void add(
      String key,
      String title,
      String description, {
      String? evidence,
    }) {
      indicators.add(
        ThreatIndicator(
          title: title,
          description: description,
          scoreContribution: 0,
          evidence: evidence,
          provenance: EvidenceProvenance.inferred,
          dedupeKey: 'context:$key',
        ),
      );
    }

    // A warning is not a request: when the credential sentence is a safety
    // instruction, none of the request-based combinations exist either.
    final requestCounts = !context.hasCredentialSignalInSafetyAdvice;

    if (requestCounts && context.hasCredentialRequest) {
      add(
        'credential-request',
        'Credential collection request',
        'The message appears to request sensitive authentication information '
            'rather than merely mentioning it.',
        evidence: context.credentialRequestSpan,
      );
    }

    if (requestCounts && context.hasCredentialRequestContext) {
      add(
        'account-credential-combination',
        'Account threat combined with credential request',
        'An account or security warning is combined with a request involving '
            'authentication information.',
        evidence: context.credentialRequestSpan,
      );
    }

    if (requestCounts &&
        context.hasCredentialRequest &&
        context.hasUrgency) {
      add(
        'urgency-credential',
        'Urgency combined with credential request',
        'Time pressure is combined with a request for authentication '
            'information.',
        evidence: context.credentialRequestSpan,
      );
    }

    if (context.hasPrizePattern && context.hasFinancialRequest) {
      add(
        'prize-financial',
        'Prize and financial request combination',
        'An unexpected reward or prize is combined with a request involving '
            'money or financial information.',
      );
    }

    if (context.hasPrizePattern && context.hasUrgency) {
      add(
        'prize-urgency',
        'Prize and urgency combination',
        'An unexpected reward is combined with pressure to act quickly.',
      );
    }

    if (context.hasHighPressureCredentialPattern) {
      add(
        'authority-secrecy-urgency-credentials',
        'High-pressure authority manipulation pattern',
        'Authority-related language is combined with secrecy, urgency, and a '
            'credential request.',
      );
    }

    if (context.hasHighPressureFinancialPattern) {
      add(
        'authority-secrecy-urgency-financial',
        'High-pressure financial manipulation pattern',
        'Authority-related language is combined with secrecy, urgency, and '
            'financial information or payment language.',
      );
    }
  }

  /// Only the indicators that actually added points, and only once each.
  ///
  /// Sorted copy, never the original list: sorting the collection the score was
  /// summed over would make the evidence order differ between runs.
  static List<ThreatIndicator> _scoredEvidence(
    List<ThreatIndicator> indicators,
  ) {
    return List.unmodifiable(
      indicators.where((i) => i.scoreContribution > 0).toList()
        ..sort((a, b) => b.scoreContribution.compareTo(a.scoreContribution)),
    );
  }

  static List<ThreatIndicator> _dedupe(List<ThreatIndicator> indicators) {
    final seen = <String>{};
    final kept = <ThreatIndicator>[];

    for (final indicator in indicators) {
      if (seen.add(indicator.identity)) kept.add(indicator);
    }

    return kept;
  }

  // --------------------------------------------------------------- scoring

  /// Distinct rule evidence plus the contextual escalation.
  ///
  /// The escalation lives here and only here. Previously each combination was
  /// an indicator with 0 points *and* a separately hard-coded bonus, so the same
  /// finding appeared twice in the breakdown while adding points in one place.
  int _calculateRiskScore(
    List<ThreatIndicator> indicators,
    _ThreatContext context,
  ) {
    var score = indicators.fold<int>(
      0,
      (total, indicator) => total + indicator.scoreContribution,
    );

    // Each combination escalates once, and only when the evidence behind it is
    // still scored — a combination whose evidence was discounted (see
    // [applyEvidenceRules]) adds nothing.
    final scoredCategories = {
      for (final indicator in indicators)
        if (indicator.scoreContribution > 0) indicator.category,
    };

    if (context.hasCredentialRequestContext &&
        !context.hasCredentialSignalInSafetyAdvice &&
        scoredCategories.contains(ThreatSignalCategory.credential)) {
      score += context.mode.credentialContextEscalation;
    }
    final credentialRequestPresent =
        context.hasCredentialRequest &&
        !context.hasCredentialSignalInSafetyAdvice;

    if (credentialRequestPresent &&
        context.hasUrgency &&
        scoredCategories.contains(ThreatSignalCategory.credential)) {
      score += context.mode.urgencyCredentialEscalation;
    }

    if (context.hasPrizePattern && context.hasFinancialRequest) {
      score += context.mode.prizeFinancialEscalation;
    }

    if (context.hasPrizePattern && context.hasUrgency) {
      score += context.mode.prizeUrgencyEscalation;
    }

    if (credentialRequestPresent &&
        context.hasHighPressureCredentialPattern &&
        scoredCategories.contains(ThreatSignalCategory.credential)) {
      score += context.mode.highPressureCredentialEscalation;
    }

    if (context.hasHighPressureFinancialPattern) {
      score += context.mode.highPressureFinancialEscalation;
    }

    return score.clamp(0, 100).toInt();
  }

  ThreatLevel _calculateLevel({
    required int score,
    required _ThreatContext context,
    required ProtectionMode mode,
    required ThreatType type,
    required String text,
  }) {
    // A category named by the facts is a threat category; the only question
    // left is how loudly to report it. Phishing, scam and social engineering
    // are always at least suspicious.
    if (type != ThreatType.legitimate) {
      final level = _threatLevel(score: score, context: context);

      // An unwanted advertisement is "spam", not "dangerous". Promotion and
      // prize wording are the only things that reach here (everything else
      // carries pressure, a request or a bad link), so demanding a floor of
      // *suspicious* — as this did — quietly labelled pure marketing as a
      // threat in Balanced mode while Strict handled it correctly.
      final scoreSaysSuspicious = score >= mode.suspiciousScoreFloor;
      if (context.hasPromotionalLanguage || context.hasPrizePattern) {
        final marketing = VerdictPolicy.isMarketingOnly(text);
        if (!marketing) return level;
        return scoreSaysSuspicious ? ThreatLevel.suspicious : level;
      }

      return level;
    }

    // No category matched. Only Strict mode may surface a sub-threshold score
    // as a category-less warning, and only when a manipulation signal exists:
    // a promotion is never a "low-confidence phishing".
    if (mode == ProtectionMode.strict &&
        score >= mode.suspiciousScoreFloor &&
        (context.hasUrgency || context.hasAccountThreat || context.hasUrl)) {
      return ThreatLevel.suspicious;
    }

    return ThreatLevel.safe;
  }

  /// URL structures that conceal the real destination or that no legitimate
  /// organisation needs: `user:pass@` userinfo, non-standard ports, punycode,
  /// IP hosts, shorteners and mixed-script names.
  static const Set<UrlSignalType> maskingSignals = {
    UrlSignalType.embeddedCredentials,
    UrlSignalType.nonStandardPort,
    UrlSignalType.punycodeHost,
    UrlSignalType.ipAddressHost,
    UrlSignalType.urlShortener,
    UrlSignalType.mixedScriptHost,
  };

  ThreatLevel _threatLevel({
    required int score,
    required _ThreatContext context,
  }) {
    // --- Original, proven combinations (order preserved) -------------------

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

    // A link plus account wording is the attack shape *when the message pushes
    // the reader through it* — "verify your account
    // immediately". The same words in a neutral announcement ("your statement
    // is ready, view it in the app") are not an attempt to move anyone.
    // A suspicious structure on the link itself is still caught above.
    if (context.hasUrl &&
        (context.hasUrgency || context.hasCredentialRequest) &&
        (context.hasAccountThreat || context.hasAccountVerificationUrlPattern)) {
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
            context.hasIdentityVerificationLanguage) &&
        // "Your OTP is 448201. Do not share it" is an advisory, not an attack,
        // even when it also warns about "unusual activity".
        !context.hasCredentialSignalInSafetyAdvice;

    final hasStrongSocialEngineeringCombination =
        context.hasAuthorityReference &&
        context.hasSecrecyPressure &&
        context.hasUrgency &&
        (context.hasStrongCredentialRequest || context.hasFinancialRequest);

    if (hasStrongPhishingCombination || hasStrongSocialEngineeringCombination) {
      return ThreatLevel.highRisk;
    }

    // --- Phase 1 additions -------------------------------------------------

    // A one-time code, PIN, or an explicit "please provide/submit your
    // password" paired with an account check is the account-takeover pattern
    // even without a link: the reply is the delivery channel. A bare "provide
    // your password to restore access" with no identified attacker stays
    // suspicious on purpose; it has the vocabulary but not the mechanism.
    if (context.hasImperativePasswordRequest &&
        (context.hasCredentialRequestContext ||
            context.hasIdentityVerificationLanguage)) {
      return ThreatLevel.highRisk;
    }

    // A link whose userinfo hides the real host (`user:pass@example.com`) is a
    // deliberately deceptive address; with a credential or verification
    // prompt behind it that is high risk even without urgency.
    if (context.hasEmbeddedCredentialsUrl &&
        (context.hasCredentialRequest ||
            context.hasAccountVerificationUrlPattern ||
            context.hasAccountThreat)) {
      return ThreatLevel.highRisk;
    }

    // Account/security wording pushed through a link, with pressure or an
    // explicit credential request behind it.
    if ((context.hasAccountThreat || context.hasAccountVerificationUrlPattern) &&
        context.hasUrl &&
        (context.hasUrgency || context.hasCredentialRequest)) {
      return ThreatLevel.highRisk;
    }

    // A credential request sent to a link. No legitimate organisation asks the
    // recipient to prove a password by following an unsolicited link.
    if (context.hasCredentialRequest &&
        context.hasUrl &&
        !context.hasCredentialSignalInSafetyAdvice) {
      return ThreatLevel.highRisk;
    }

    // A simple account-information verification request through an
    // organization/service desk should not become suspicious solely
    // because its additive score crosses the floor.
    if (context.hasAccountThreat &&
        context.hasAuthorityReference &&
        !context.hasUrgency &&
        !context.hasCredentialRequest &&
        !context.hasFinancialRequest &&
        !context.hasPrizePattern &&
        !context.hasUrl) {
      return ThreatLevel.safe;
    }

    // --- Sensitivity floor -------------------------------------------------

    // The protection mode's floor is the user's choice of how much borderline
    // evidence is worth surfacing. It used to be displayed on the Shield tab
    // and read by nothing, so Relaxed and Strict produced identical verdicts.
    if (score >= context.mode.suspiciousScoreFloor) {
      return ThreatLevel.suspicious;
    }

    // A request for a credential or payment is not "borderline" the way a
    // bare score is: it is the shape of the attack, so it stays suspicious even
    // below the floor.
    //
    // A prize keeps its own floor. `_classifyThreat` labels a prize "spam" only
    // when it asks for nothing, and the evaluation set pins such a message as
    // *suspicious* on the strength of the offer itself — the sender is inviting
    // the reader to claim money, which is the unsolicited-lure shape even when
    // no fee is named. Level (how loudly) and type (unwanted, not a scam) are
    // separate questions.
    if (context.hasCredentialRequest ||
        context.hasPrizePattern ||
        context.hasFinancialRequest) {
      return ThreatLevel.suspicious;
    }

    // Marketing copy carrying no request is spam, not a threat: the honest
    // label is "unwanted", not "dangerous".
    if (context.hasPromotionalLanguage) {
      return ThreatLevel.suspicious;
    }

    return ThreatLevel.safe;
  }

  /// True when the message is news about a job or an application, as opposed
  /// to an offer of money or goods.
  ///
  /// Kept here as the single definition; [VerdictPolicy.benignContext] uses the
  /// same test, so the two can never disagree about what a job message is.
  @visibleForTesting
  static bool isApplicationOutcome(String text) {
    return VerdictPolicy.looksLikeApplicationOutcome(text);
  }

  ThreatType _classifyThreat(
    _ThreatContext context,
    String text,
    SignalFeatures features,
  ) {
    // 0. The message warns the reader against an attack rather than making
    //    one. Checked first, because education about phishing naturally quotes
    //    the phishing phrases it describes — "we have been notified of a
    //    security alert, verify your account, reset your password, never click
    //    links in e-mails" would otherwise score every rule at once.
    if (VerdictPolicy.isSecurityEducation(text, features)) {
      return ThreatType.legitimate;
    }
    /*
     * Specific contextual patterns are evaluated before broader
     * categories. This prevents credential-related language from
     * automatically turning authority-based social-engineering messages
     * into phishing.
     */
    // 1. Trials and reward offers. A prize with no demand at all is marketing
    //    ("a special reward for selected customers"); a prize that demands
    //    money, account numbers or card details is a scam. Congratulating
    //    someone on a job or an interview is not a prize at all.
    if (context.hasPrizePattern &&
        !context.hasFinancialRequest &&
        !context.hasCredentialRequest &&
        !context.hasUrl) {
      return isApplicationOutcome(text)
          ? ThreatType.legitimate
          : ThreatType.spam;
    }

    // 1b. A prize plus a demand is a scam, whatever else is present: the
    //     reward is the bait and the demand is the theft. A job message is
    //     exempt: "congratulations, you are shortlisted" is not bait.
    if (context.hasPrizePattern && !isApplicationOutcome(text)) {
      return ThreatType.scam;
    }

    // 2. An authority asking for money *and* secrecy is someone impersonating
    //    an organisation to move funds — "do not tell anyone" is the technique,
    //    not the goal. Likewise a self-declared "bank security department" is
    //    the social-engineering shape even when its target is a code rather than
    //    cash. Social engineering wins over the phishing label here because the
    //    impersonation is what the message is built around.
    if (context.hasAuthorityReference &&
        context.hasFinancialRequest &&
        context.hasSecrecyPressure) {
      return ThreatType.socialEngineering;
    }

    // A named bank "security" department asking for a code is the social
    // engineering shape, but a message that *warns* about sharing codes is not
    // asking for one. Requiring the request keeps fraud advisories safe.
    if (context.hasBankSecurityReference &&
        context.hasCredentialRequest &&
        !context.hasCredentialSignalInSafetyAdvice) {
      return ThreatType.socialEngineering;
    }

    // 2. An authority asking for money is the scam shape, not social
    //    engineering: the point of impersonating a delivery company or a tax
    //    office is the payment.
    if (context.hasAuthorityReference && context.hasFinancialRequest) {
      return ThreatType.scam;
    }

    // A message that tells the reader not to share a credential is a warning,
    // not an attack. It is reported below the decision ladder only when the
    // scorer has confirmed the credential evidence was discounted.
    if (context.hasCredentialSignalInSafetyAdvice) {
      return ThreatType.legitimate;
    }

    // 3. Account verification through a link, or with an identity claim.
    if ((context.hasAccountVerificationUrlPattern ||
            (context.hasAccountThreat &&
                context.hasIdentityVerificationLanguage))) {
      return ThreatType.phishing;
    }

    // 4. Authority + pressure + a demand from the reader. A named organisation
    //    that wants a PIN or a code — "your delivery service needs your PIN"
    //    — is the social-engineering shape. _threatLevel still decides whether
    //    it is loud enough to be called high risk.
    if (context.hasAuthorityReference &&
        context.hasUrgency &&
        (context.hasCredentialRequest || context.hasFinancialRequest)) {
      return ThreatType.socialEngineering;
    }

    if (context.hasAuthorityReference &&
        (context.hasUrgency || context.hasSecrecyPressure) &&
        (context.hasCredentialRequest || context.hasFinancialRequest)) {
      return ThreatType.socialEngineering;
    }

    if (context.hasAuthorityReference &&
        context.hasSecrecyPressure &&
        context.hasUrgency &&
        (context.hasStrongCredentialRequest || context.hasFinancialRequest)) {
      return ThreatType.socialEngineering;
    }

    // 5. An authority asking for a credential without an account context is
    //    social engineering ("delivery service needs your PIN"); with account
    //    context it is an impersonated account check, i.e. phishing.
    if (context.hasAuthorityReference &&
        context.hasCredentialRequest &&
        !context.hasCredentialRequestContext) {
      return ThreatType.socialEngineering;
    }

    if ((context.hasCredentialRequestContext ||
            context.hasCredentialRequest && context.hasAccountThreat) &&
        !context.hasAuthorityReference) {
      return ThreatType.phishing;
    }

    if (context.hasAuthorityReference &&
        (context.hasCredentialRequest || context.hasFinancialRequest)) {
      return ThreatType.socialEngineering;
    }

    if (context.hasCredentialRequest) {
      return ThreatType.phishing;
    }

    if (context.hasCredentialSignal && context.hasUrl) {
      return ThreatType.phishing;
    }

    // 6. Money demanded is a scam whatever else is in the message.
    if (context.hasFinancialRequest) {
      return ThreatType.scam;
    }

    // 7. An account warning plus a request for the credential is an
    //    impersonated account check — phishing — even when the sender claims
    //    the name of an organisation. This is checked after the social-
    //    engineering shapes above, so named-authority impersonation still wins.
    if (context.hasCredentialRequest && context.hasAccountThreat) {
      return ThreatType.phishing;
    }

    // 8. Marketing copy that carries no request is spam, not a threat.
    if (context.hasPromotionalLanguage || context.hasPrizePattern) {
      return ThreatType.spam;
    }

    // 8. A credential mentioned alongside an account warning: phishing, but
    //    see _threatLevel — a bare mention (an advisory saying a code "will
    //    be sent") does not reach high risk.
    if (context.hasCredentialSignal && context.hasAccountThreat) {
      return ThreatType.phishing;
    }

    // 9. Suspicious against the user's sensitivity floor. Pressure or an
    //    account warning is the signal that matched, so spam is the least
    //    over-claiming label.
    if (context.hasUrgency || context.hasAccountThreat || context.hasUrl) {
      return ThreatType.spam;
    }

    // 10. Anything else that reached here has no threat vocabulary and no
    //     link: nothing about it is evidence of anything, and Strict mode must
    //     not invent a category to justify its lower floor.
    return ThreatType.legitimate;
  }

  /// The user-facing explanation for a verdict, derived from the category
  /// alone.
  ///
  /// Category and level are one verdict, not two: a message can be *labelled*
  /// "suspicious" without having a threat category (Strict mode's lower
  /// floor), and the summary has to say that. Passing them together is what
  /// stops a screen from pairing "Suspicious" with "No major threat indicators
  /// were detected."
  ///
  /// [ThreatAnalysis.summary] keeps the wording it always had; the verifier
  /// in `VerdictPolicy` adds the "flagged only because your sensitivity is
  /// Strict" clause for that exact case.
  static String describeSummary(ThreatType type, ThreatLevel level) {
    if (type == ThreatType.legitimate) {
      // Strict mode's lower floor can surface weak signals without a category.
      return 'This message contained weak signals but did not match a threat '
          'category. It was flagged only because your sensitivity is Strict.';
    }

    switch (type) {
      case ThreatType.phishing:
        return 'This message contains patterns commonly associated with phishing attempts.';
      case ThreatType.scam:
        return 'This message contains patterns commonly associated with scams or deceptive offers.';
      case ThreatType.socialEngineering:
        return 'This message contains multiple signals associated with social-engineering techniques.';
      case ThreatType.spam:
        // Level and category are separate questions: an unwanted advertisement
        // is not made "dangerous" by a high score, so the wording does not
        // change with the level.
        return 'This message contains signals that may indicate unsolicited or suspicious communication.';
      case ThreatType.legitimate:
        // Handled above; unreachable here but required for exhaustiveness.
        return 'No major threat indicators were detected.';
    }
  }

  String _createSummary(ThreatType type, ThreatLevel level) {
    if (level == ThreatLevel.safe) {
      return 'No major threat indicators were detected.';
    }

    return ThreatAnalyzer.describeSummary(type, level);
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

    if (type == ThreatType.legitimate) {
      return 'Nothing matched a known threat pattern. If the message asks for a '
          'password, a one-time code or a payment, verify the sender through '
          'an official channel before responding.';
    }

    return 'Be cautious with this message. Avoid providing sensitive information or following instructions until the sender is independently verified.';
  }
}

/// One immutable snapshot of the contextual facts behind a verdict.
///
/// Built in exactly one place from [SignalFeatures], so adding a signal means
/// adding it once, in a type the compiler will force every constructor call to
/// acknowledge.

class _ThreatContext {
  final bool hasCredentialSignal;
  final bool hasCredentialRequest;
  final bool hasStrongCredentialRequest;
  final bool hasImperativePasswordRequest;

  /// True when a link carries `user:pass@` before the host.
  final bool hasEmbeddedCredentialsUrl;
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
  final bool hasHighPressureCredentialPattern;
  final bool hasHighPressureFinancialPattern;
  final bool hasCredentialSignalInSafetyAdvice;
  final String? credentialRequestSpan;

  /// True when any link uses a structure that conceals where it really goes.
  final bool hasMaskingUrl;

  /// The mode whose escalation weights apply. Carried on the context so the
  /// score function does not need a second parameter that could disagree with
  /// the level calculation.
  final ProtectionMode mode;

  const _ThreatContext({
    required this.mode,
    required this.hasCredentialSignal,
    required this.hasCredentialRequest,
    required this.hasStrongCredentialRequest,
    required this.hasImperativePasswordRequest,
    this.hasEmbeddedCredentialsUrl = false,
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
    required this.hasHighPressureCredentialPattern,
    required this.hasHighPressureFinancialPattern,
    required this.hasCredentialSignalInSafetyAdvice,
    this.credentialRequestSpan,
    this.hasMaskingUrl = false,
  });

  factory _ThreatContext.build({
    required ProtectionMode mode,
    required String text,
    required SignalFeatures features,
    required bool hasUrl,
    required List<UrlAnalysis> urlAnalyses,
  }) {
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

    final hasMaskingUrl = urlAnalyses.any(
      (analysis) => analysis.signals.any(
        (signal) => ThreatAnalyzer.maskingSignals.contains(signal.type),
      ),
    );

    final hasCredentialRequestContext =
        features.hasCredentialRequest &&
        (features.hasAccountVerificationLanguage ||
            features.hasIdentityVerificationLanguage ||
            features.hasAccountThreat);

    return _ThreatContext(
      mode: mode,
      hasAccountVerificationUrlPattern:
          features.hasAccountVerificationLanguage &&
          features.hasUrgency &&
          hasUrl,
      hasAccountThreatWithSuspiciousUrl:
          features.hasAccountThreat &&
          features.hasAccountVerificationLanguage &&
          hasSuspiciousUrlStructure,
      hasCredentialSignal: features.hasCredentialSignal,
      hasCredentialRequestContext: hasCredentialRequestContext,
      hasIdentityVerificationLanguage: features.hasIdentityVerificationLanguage,
      hasCredentialRequest: features.hasCredentialRequest,
      hasAccountThreat: features.hasAccountThreat,
      hasUrgency: features.hasUrgency,
      hasPrizePattern: features.hasPrizePattern,
      hasFinancialRequest: features.hasFinancialRequest,
      hasAuthorityReference: features.hasAuthorityReference,
      hasSecrecyPressure: features.hasSecrecyPressure,
      hasPromotionalLanguage: features.hasPromotionalLanguage,
      hasBankSecurityReference: _containsAny(text, _bankSecurityPhrases),
      hasStrongCredentialRequest: features.hasStrongCredentialRequest,
      hasImperativePasswordRequest: features.hasImperativePasswordRequest,
      hasEmbeddedCredentialsUrl: urlAnalyses.any(
        (analysis) => analysis.signals.any(
          (signal) => signal.type == UrlSignalType.embeddedCredentials,
        ),
      ),
      hasUrl: hasUrl,
      hasHighPressureCredentialPattern:
          features.hasAuthorityReference &&
          features.hasSecrecyPressure &&
          features.hasUrgency &&
          features.hasStrongCredentialRequest,
      hasHighPressureFinancialPattern:
          features.hasAuthorityReference &&
          features.hasSecrecyPressure &&
          features.hasUrgency &&
          features.hasFinancialRequest,
      hasCredentialSignalInSafetyAdvice: _isSafetyAdvice(
        text: text,
        features: features,
      ),
      credentialRequestSpan: features.credentialRequestSpan,
      hasMaskingUrl: hasMaskingUrl,
    );
  }

  /// A *specific* impersonated authority, not the broad `authority` category.
  /// Evidence for the OTP social-engineering rule below.
  static const List<String> _bankSecurityPhrases = [
    'bank security',
    'bank security department',
    'bank security team',
    'bank security officer',
  ];

  static bool _containsAny(String text, List<String> phrases) {
    return phrases.any((phrase) => TextMatcher.contains(text, phrase));
  }

  /// A message that tells the reader *not* to share credentials — a bank's
  /// fraud warning, an awareness page — is not asking for one. This is the one
  /// context where the credential rule is deliberately suppressed, and it
  /// requires both a credential mention and an explicit safety phrase.
  static bool _isSafetyAdvice({
    required String text,
    required SignalFeatures features,
  }) {
    if (!features.hasCredentialSignal) return false;
    return SignalFeatures.isSafetyAdvice(text);
  }
}
