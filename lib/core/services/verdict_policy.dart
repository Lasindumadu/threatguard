import '../models/channel_profile.dart';
import '../models/hybrid_threat_analysis.dart';
import '../models/ml_feature_vector.dart';
import '../models/ml_prediction.dart';
import '../models/protection_mode.dart';
import '../models/threat_analysis.dart';
import 'signal_features.dart';
import 'text_matcher.dart';
import 'threat_analyzer.dart';
import 'url_analyzer.dart';
import 'url_extractor.dart';

/// The single place where a raw [ThreatAnalysis] + [MlPrediction] pair becomes a
/// final [HybridThreatAnalysis].
///
/// Before this existed, verdict mapping lived inside the widget-facing engine
/// *and* partly inside the hybrid analyzer, so the same facts could produce a
/// different final level depending on which entry point ran them. The policy
/// now runs in exactly one order:
///
///  1. Decide *what* the message most likely is (`type`), via the caller's
///     arbitration result.
///  2. Decide *how much risk to communicate* (level), applying benign-context
///     adjustments and the protection-mode floor.
///  3. Strip anything that would overstate certainty.
///
/// This file is pure: it takes values and returns a value. No storage, no
/// clock, no I/O, so every rule here is unit-testable without a widget tree.
class VerdictPolicy {
  const VerdictPolicy._();

  /// Verb forms that request money. Used only to tell "pay this fee" apart from
  /// "your payment was received".
  static const List<String> _paymentRequestPhrases = [
    'pay now',
    'pay a fee',
    'pay the fee',
    'pay fee',
    'payment required',
    'pay to release',
    'make a payment',
    'send money',
    'transfer money',
    'fee required',
    'required payment',
  ];

  /// Language that marks an ordinary money *notification* rather than a
  /// request: a completed transaction, a balance, a due date.
  static const List<String> _moneyNotificationPhrases = [
    'was debited',
    'has been debited',
    'debited',
    'was credited',
    'has been credited',
    'credited',
    'transaction',
    'balance',
    'statement',
    'available balance',
    'payment received',
    'payment successful',
    'due on',
    'due date',
  ];

  /// Shapes that mark a message as *education about* a scam rather than a
  /// scam. Each is specific enough not to be usable as a disguise, and each
  /// must share a sentence with the threat vocabulary it explains.
  static final List<RegExp> _educationShapes = [
    // "Learn how phishing works", "learn how attackers…"
    RegExp(r'\b(?:learn|find out|understand)\s+(?:how|about|why)\b'),
    // "how phishing works", "how scams work", "how fraudsters operate"
    RegExp(
      r'\bhow\s+(?:phishing|scams?|fraud|fake\s+\w+|attackers|scammers|'
      r'criminals)\s+\w+',
    ),
    // "what is phishing", "what a phishing message looks like"
    RegExp(r'\bwhat\s+(?:is|are|a)\b.*\b(?:phishing|scam|fraud)\b'),
    // "beware of phishing", "watch out for fake delivery texts"
    RegExp(
      r'\b(?:beware of|watch out for)\b.*\b(?:phishing|scam|fraud|fake)\b',
    ),
    // "report it to the bank", "report this message to your bank"
    RegExp(
      r'\breport\s+(?:it|this|these)\b.*\b(?:bank|police|organisation|organization|app)\b',
    ),
    // "we have been notified", "we received reports" — the organisation
    // speaking *about* a problem, rather than an attacker claiming one.
    RegExp(
      r'\b(?:we have been notified|we have noticed|we have seen|we received|'
      r'have you received|beware|be careful|reminder|scam alert|fraud alert)\b',
    ),
  ];

  /// Timing words that appear in spam and in ordinary scheduling alike. They
  /// only count as *pressure* next to an action word ("pay", "claim",
  /// "respond"), never on their own.
  static const List<String> _timingWords = [
    'today',
    'tomorrow',
    'this week',
    'by friday',
    'by monday',
  ];

  static const List<String> _actionWords = [
    'pay',
    'claim',
    'click',
    'respond',
    'respond by',
    'reply',
    'verify',
    'confirm',
    'expires',
    'apply',
  ];

  /// Recognisable message shapes that a security product must not treat as an
  /// attack just because they contain sensitive vocabulary.
  ///
  /// Returns a short description of the benign shape, or null.
  static String? benignContext(String text, SignalFeatures features) {
    if (text.trim().isEmpty) return null;

    if (_isTransactionNotification(text, features)) {
      return 'a transaction or balance notification';
    }

    if (_isApplicationOutcome(text)) {
      return 'a job or application update';
    }

    if (SignalFeatures.isSafetyAdvice(text)) {
      return 'a security warning that tells the reader not to share credentials';
    }

    if (_isSecurityEducation(text, features)) {
      return 'security education about how scams work';
    }

    if (_isDeliveryProgress(text, features)) {
      return 'a delivery or parcel tracking update';
    }

    if (isSchedulingOnly(text, features)) {
      return 'a scheduling message with no action demanded';
    }

    if (_isSelfServiceRecovery(text, features)) {
      return 'a password reset you (or someone with your account) requested';
    }

    return null;
  }

  /// A completed money movement with no request for anything.
  static bool _isTransactionNotification(String text, SignalFeatures f) {
    if (f.hasCredentialRequest) return false;
    if (_containsAny(text, _paymentRequestPhrases)) return false;
    if (f.hasPrizePattern) return false;
    if (f.hasUrgency && f.hasSecrecyPressure) return false;

    if (_containsAny(text, _moneyNotificationPhrases) &&
        !_containsAny(text, [
          'call',
          'contact us',
          'click',
          'visit',
          'verify',
        ])) {
      return true;
    }

    return false;
  }

  /// A bare timing word is not pressure. "Delivery between 2pm and 5pm today"
  /// is scheduling; "pay the fee today or lose the parcel" is pressure. The
  /// rule engine's `urgency` category cannot tell them apart, so this context
  /// check does.
  static bool isSchedulingOnly(String text, SignalFeatures f) {
    if (!f.hasUrgency) return false;

    final hasAction = _containsAny(text, _actionWords);
    if (hasAction) return false;

    // "call the number on the back of your card immediately" is an action and
    // a timing word, which made a bank fraud alert look like scheduling. An
    // independent contact channel is the opposite of pressure.
    if (SignalFeatures.isIndependentChannelCue(text)) return false;

    return _containsAny(text, _timingWords);
  }

  /// A bare "offer" is not spam. Recruitment, product updates and newsletters
  /// use the word without any promotional intent, and flagging them is noise.
  static bool isPromotionalMarketing(String text, SignalFeatures f) {
    if (!f.hasPromotionalLanguage) return false;

    return _containsAny(text, _promotionalCues);
  }

  static const List<String> _promotionalCues = [
    'special offer',
    'limited time',
    'discount',
    'off',
    'sale',
    'subscribe',
    'promotional',
    'selected customers',
    'selected products',
    'limited number',
    'free reward',
    'special reward',
    'buy now',
    'shop',
  ];

  /// "You have been shortlisted for the software engineer position".
  static bool looksLikeApplicationOutcome(String text) =>
      _isApplicationOutcome(text);

  /// "You have been shortlisted for the software engineer position".
  static bool _isApplicationOutcome(String text) {
    if (!_containsAny(text, [
      'shortlisted',
      'interview',
      'application',
      'position',
      'candidate',
      'we regret',
      'offer letter',
      'job',
      'vacancy',
    ])) {
      return false;
    }

    // A genuine outcome never asks for money or codes.
    return !_containsAny(text, [
      'pay',
      'processing fee',
      'registration fee',
      'send your',
      'provide your',
      'sharing fee',
    ]);
  }

  /// Education about a scam rather than a scam.
  ///
  /// Public so the rule engine and the verdict policy use one definition. A
  /// phishing message may quote the same advice, so the test requires a
  /// descriptive frame, a message that is mostly a warning, and no demand
  /// anywhere.
  static bool isSecurityEducation(String text, SignalFeatures features) =>
      _isSecurityEducation(text, features);

  /// A bank or app telling users how phishing works, without requesting
  /// anything.
  ///
  /// Three rules keep this from becoming a blanket escape hatch for phishing
  /// copy:
  ///
  ///  * **No demand, anywhere.** A real advisory never asks for a code, a
  ///    payment or a signature term.
  ///  * **A descriptive frame.** At least one sentence must talk *about* scams
  ///    ("how phishing works", "we have been notified about…").
  ///  * **An advisory proportion, and no link.** Safety commands must outnumber
  ///    the credential-bearing sentences, and there must be no masked link. A
  ///    single "never click" appended to a phishing lure is not advice, and an
  ///    advisory is read, not clicked.
  ///
  /// A quoted lure ("banks will never ask you to send your OTP", "a message
  /// asking you to verify your account") is *described*, not requested, so a
  /// sentence that only quotes a request is left out of the no-demand test.
  /// Phase 1 finding: without that, a bank's own security reminder was rated
  /// phishing/high-risk for repeating the trick it was warning about.
  static bool _isSecurityEducation(String text, SignalFeatures f) {
    if (f.hasFinancialRequest) return false;
    if (f.hasPrizePattern || f.hasSecrecyPressure) return false;

    // Sentences are already trimmed and lower-cased by the shared splitter;
    // this function used to re-split with a different boundary rule.
    final sentences = SignalFeatures.splitSentences(text);
    // A quoted lure ("a message asking you to send your OTP") is described,
    // not requested: it is the thing the advisory warns about. Sentences that
    // merely quote are left out of the "no demand" test, so an advisory that
    // names the trick is not scored as the trick. A real lure is not framed
    // this way.
    final quoted = sentences.where(SignalFeatures.isQuotedContext).toList();
    final unquoted = [
      for (final sentence in sentences)
        if (!SignalFeatures.isQuotedContext(sentence)) sentence,
    ].join('. ');

    if (f.hasCredentialRequest && quoted.isEmpty) return false;
    var hasEducationFrame = false;
    var safetySentences = 0;
    var credentialSentences = 0;

    for (final sentence in sentences) {
      final lower = sentence;
      if (lower.isEmpty) continue;

      if (_educationShapes.any((r) => r.hasMatch(lower))) {
        hasEducationFrame = true;
      }

      if (SignalFeatures.hasSafetyCommand(lower)) {
        safetySentences++;
      } else if (_containsAny(lower, [
        'password',
        'otp',
        'pin',
        'verification code',
        'account',
        'link',
      ])) {
        credentialSentences++;
      }
    }

    final hasMaskedLink = UrlExtractor.extract(text).any(
      (url) => const UrlAnalyzer()
          .analyze(url)
          .signals
          .any(ThreatAnalyzer.maskingSignals.contains),
    );

    return hasEducationFrame &&
        safetySentences > credentialSentences &&
        !hasMaskedLink &&
        // An advisory never asks for anything outside its quotes.
        SignalFeatures.requestSpan(unquoted) == null;
  }

  /// The self-service flow for a password the user has already forgotten.
  ///
  /// "Use this link to reset your password" is not a request for a password:
  /// it is the standard remedy. What it is *not* is evidence that the sender is
  /// trustworthy, so this only explains the score — it does not clear it.
  static bool _isSelfServiceRecovery(String text, SignalFeatures f) {
    if (f.hasCredentialRequest) return false;
    if (f.hasFinancialRequest) return false;
    if (f.hasPrizePattern) return false;
    if (f.hasAccountThreat) return false;
    if (f.hasUrgency || f.hasSecrecyPressure) return false;

    return _containsAny(text, [
      'reset your password',
      'reset your pin',
      'forgot your password',
      'forgotten your password',
      'password reset',
    ]);
  }

  /// A parcel in transit with a tracking reference, and no fee demand.
  static bool _isDeliveryProgress(String text, SignalFeatures f) {
    if (f.hasCredentialRequest) return false;
    if (f.hasFinancialRequest) return false;
    if (_containsAny(text, _paymentRequestPhrases)) return false;
    if (f.hasPrizePattern) return false;

    return _containsAny(text, [
      'has been dispatched',
      'out for delivery',
      'will be delivered',
      'has been delivered',
      'delivery scheduled',
      'tracking number',
      'track your',
      'ready for collection',
    ]);
  }

  static bool _containsAny(String text, List<String> phrases) {
    return TextMatcher.containsAny(text, phrases);
  }

  /// Applies the benign-context adjustment to a rule verdict.
  ///
  /// The adjustment is narrow on purpose: it can only lower a *suspicious*
  /// verdict to safe, never clear a high-risk one, and it never suppresses the
  /// evidence or the score. If a benign-looking message still trips a
  /// high-risk combination, the combination wins — that is the direction that
  /// fails safe.
  static ThreatAnalysis applyBenignContext(
    ThreatAnalysis analysis, {
    required String? benignReason,
    bool promotional = false,
  }) {
    // "Offer" alone is not spam. Recruitment, product updates and newsletters
    // use it without promotional intent; only real marketing cues match.
    if (promotional && analysis.level == ThreatLevel.suspicious) {
      // `copyWith`, not a manual rebuild: the previous rebuild silently dropped
      // `supportingEvidence` (and would have dropped any future field), so a
      // downgraded verdict lost the facts that made it look genuine.
      return analysis.copyWith(
        level: ThreatLevel.safe,
        type: ThreatType.legitimate,
        summary:
            'The word "offer" matched a marketing rule, but the message is not '
            'an advertisement. No threat indicators were confirmed.',
        recommendation:
            'Nothing here asks you to send credentials, money or codes.',
      );
    }

    if (benignReason == null) return analysis;

    // A warning is not a request, and that is a fact about the text rather
    // than a matter of degree: it clears regardless of level.
    final isWarning = analysis.indicators.any(
      (i) => i.dedupeKey == 'context:credential-warning',
    );

    if (analysis.level == ThreatLevel.highRisk && !isWarning) return analysis;

    return analysis.copyWith(
      level: ThreatLevel.safe,
      type: ThreatType.legitimate,
      summary:
          'Sensitive words are present, but this reads like $benignReason. '
          'No threat indicators were confirmed.',
      recommendation:
          'Nothing here asks you to send credentials, money or codes. '
          'Still verify large transactions through your bank\'s official app.',
    );
  }

  /// Evidence that *supports* a message being genuine.
  ///
  /// Kept separate from [ThreatIndicator] on purpose: an indicator is a reason
  /// to worry, and merging "this reuses the same wording as phishing" with
  /// "this is what makes us think it is genuine" is how a security product
  /// becomes unreadable. Only spans in sentences that contain no request are
  /// counted — a demand in the same sentence removes every prop from it.
  static final RegExp _positive = RegExp(
    r'\b(?:was|has been|have been)\s+(?:successfully\s+)?'
    r'(?:debited|credited|received|delivered|dispatched|confirmed|processed|booked)\b'
    r'|\b(?:balance|statement|reference|tracking number|order number|booking)\b'
    r'|\b(?:shortlisted|interview|application|candidate|position|offer letter)\b'
    r'|\b(?:never share|do not share|do not click|do not give|will never ask)\b',
    unicode: true,
  );

  static final RegExp _demandInSentence = RegExp(
    r'\b(?:share|send|provide|enter|confirm|submit|reply with|pay|transfer)\s+'
    r'(?:your\s+)?(?:password|pin|otp|code|card|account number|details|fee|money)\b',
    unicode: true,
  );

  static List<String> positiveSignals(String text) {
    final lower = text.toLowerCase();
    final found = <String>{};

    for (final sentence in lower.split(RegExp(r'(?<=[.!?])\s+|\n+'))) {
      if (_demandInSentence.hasMatch(sentence)) continue;

      for (final match in _positive.allMatches(sentence)) {
        found.add(match.group(0)!.replaceAll(RegExp(r'\s+'), ' '));
      }
    }

    return found.toList();
  }

  /// The explanation shown when a credential was mentioned only as a warning.
  static const ThreatIndicator credentialWarningIndicator = ThreatIndicator(
    title: 'Credential warning, not credential collection',
    description:
        'The message mentions a password, code or PIN only to tell the reader '
        'not to share it. That is a security warning, not a request.',
    scoreContribution: 0,
    provenance: EvidenceProvenance.inferred,
    dedupeKey: 'context:credential-warning',
  );

  /// True when the only reason a message looks like spam is marketing
  /// vocabulary, with no demand of any kind.
  ///
  /// "Offer" is the clearest example: a job offer, a product update and a
  /// newsletter all contain it, and none of them is a threat.
  static bool isMarketingOnly(String text) {
    final hasMarketingCue = _containsAny(text, _marketingCues);
    if (!hasMarketingCue) return false;

    return !_containsAny(text, [
      ..._paymentRequestPhrases,
      ...SignalFeatures.credentialRequestPhrases,
      ...SignalFeatures.strongCredentialRequestPhrases,
      'claim your prize',
      'claim now',
      'you won',
      'you have won',
      'lottery',
    ]);
  }

  static const List<String> _marketingCues = [
    'special offer',
    'limited time offer',
    'offer',
    'subscribe',
    'discount',
    'promotional',
    'selected customers',
    'selected products',
    '50% off',
    'buy now',
    'shop',
  ];

  /// Promotes a model-only detection to at least "suspicious" in the UI.
  ///
  /// The rule engine may have found nothing (or cleared a benign shape) while
  /// the model still saw a threat pattern. Reporting that as "safe" would hide
  /// real evidence; reporting it as "high risk" would overstate a model-only
  /// call. Suspicious is the honest middle.
  static ThreatLevel levelFor({
    required ThreatAnalysis analysis,
    required ThreatType finalType,
    required VerdictSource source,
  }) {
    if (finalType == ThreatType.legitimate) return ThreatLevel.safe;
    if (source == VerdictSource.machineLearning ||
        source == VerdictSource.modelOverride) {
      return ThreatLevel.suspicious;
    }
    return analysis.level;
  }

  /// Builds the single authoritative analysis result.
  ///
  /// The caller supplies the arbitration decision (`finalType`, `source`,
  /// `rationale`) and the message context (mode, channel). This method owns
  /// everything that happens *after* arbitration: benign-context adjustment,
  /// the level floor for model-only calls, and the channel bonus.
  static HybridThreatAnalysis assemble({
    required ThreatAnalysis ruleAnalysis,
    required MlPrediction mlPrediction,
    required ThreatType finalType,
    required VerdictSource source,
    required String rationale,
    required ProtectionMode mode,
    ChannelProfile? channel,
    String? benignReason,
    bool promotional = false,
    double agreement = 0.0,
    // Set only by a trusted external report; on-device callers leave it null.
    EvidenceConfidence? confirmation,
  }) {
    final adjusted = finalType == ThreatType.legitimate
        ? applyBenignContext(
            ruleAnalysis,
            benignReason: benignReason,
            promotional: promotional,
          )
        : ruleAnalysis;

    final effectiveType = finalType == ThreatType.legitimate
        ? adjusted.type
        : finalType;

    final effectiveRationale =
        (finalType == ThreatType.legitimate &&
            benignReason != null &&
            ruleAnalysis.type != ThreatType.legitimate)
        ? '$rationale The message reads like $benignReason, so its sensitive '
              'vocabulary was not treated as an attack.'
        : rationale;

    final hasUrl = ruleAnalysis.detectedUrls.isNotEmpty;
    final channelBonus = (channel == null || !hasUrl || !mode.applyChannelRisk)
        ? 0
        : channel.urlRiskBonus;

    // A verdict can be *labelled* suspicious without naming a threat category:
    // Strict mode's lower floor surfaces weak signals, and the rule engine then
    // keeps the category legitimate on purpose. Saying "nothing major was
    // detected" next to "Suspicious" is a contradiction, so the one case that
    // produced it is described explicitly.
    final summary =
        effectiveType == ThreatType.legitimate &&
            adjusted.level == ThreatLevel.suspicious
        ? 'Weak manipulation signals were detected, but they did not match a '
              'threat category. Flagged only because your sensitivity is '
              '${mode.label}.'
        : adjusted.summary;

    return HybridThreatAnalysis(
      ruleAnalysis: summary == adjusted.summary
          ? adjusted
          : adjusted.copyWith(summary: summary),
      mlPrediction: mlPrediction,
      finalType: effectiveType,
      source: source,
      rationale: effectiveRationale,
      agreement: agreement,
      protectionMode: mode,
      channel: channel,
      channelRiskBonus: channelBonus,
      confirmedEvidence: confirmation,
    );
  }

  /// A verdict confirmed by an external, trusted report (a takedown list, a
  /// reputation service that returned `malicious`, the user's own report).
  ///
  /// This is the **only** way an analysis reaches
  /// [EvidenceConfidence.confirmedThreat]. On-device heuristics must not call
  /// this no matter how high their score: a phrase match and a logistic
  /// regression are inferences about wording, not confirmation about intent.
  /// Kept here so the distinction lives in the verdict model rather than in a
  /// screen, and so any future integration has one place to plug into.
  ///
  /// The verdict still needs a threat category: a confirmed report about a
  /// message that matched no rule is reported as phishing at most, because the
  /// category is the app's best label, not part of the confirmation.
  static HybridThreatAnalysis confirmedByExternalReport({
    required ThreatAnalysis ruleAnalysis,
    required MlPrediction mlPrediction,
    required ThreatType finalType,
    required String rationale,
    required ProtectionMode mode,
    ChannelProfile? channel,
  }) {
    return assemble(
      ruleAnalysis: ruleAnalysis,
      mlPrediction: mlPrediction,
      finalType: finalType == ThreatType.legitimate
          ? ThreatType.phishing
          : finalType,
      source: VerdictSource.externalReport,
      rationale: rationale,
      mode: mode,
      channel: channel,
      confirmation: EvidenceConfidence.confirmedThreat,
    );
  }

  /// The placeholder used when no analysis was possible.
  ///
  /// It is explicitly *not* a "safe" verdict: [HybridThreatAnalysis.isAnalysed]
  /// is false and the UI renders the reason instead of a green banner.
  static HybridThreatAnalysis unavailable({
    required String reason,
    required ProtectionMode mode,
    ChannelProfile? channel,
    VerdictSource source = VerdictSource.none,
  }) {
    return HybridThreatAnalysis(
      ruleAnalysis: ThreatAnalysis(
        riskScore: 0,
        level: ThreatLevel.safe,
        type: ThreatType.legitimate,
        indicators: const [],
        detectedUrls: const [],
        summary: 'Not analysed.',
        recommendation: 'Nothing was analysed, so no verdict was reached.',
        mode: mode,
      ),
      mlPrediction: const MlPrediction(
        type: MlThreatType.legitimate,
        confidence: 0.0,
        probabilities: [],
      ),
      finalType: ThreatType.legitimate,
      source: source,
      rationale: reason,
      agreement: 0.0,
      protectionMode: mode,
      channel: channel,
      channelRiskBonus: 0,
      unavailableReason: reason,
    );
  }
}
