import '../models/threat_signal.dart';
import 'threat_rule_catalog.dart';
import 'text_matcher.dart';

/// Shared, single-pass extraction of the message facts every engine needs.
///
/// Before this existed, `ThreatAnalyzer` and `MlFeatureExtractor` each carried
/// their own copies of the credential-request phrase lists (threading/OTP
/// request, strong request, account verification, identity verification). They
/// had already drifted — the analyzer knew `send otp`/`send pin` while the
/// model had never heard of them — so the rule engine and the model were
/// judging the same message on different evidence. Both engines now read from
/// one [SignalFeatures] value, which both fixes the drift and halves the
/// per-message matching cost (the expensive scans run once, not twice).
///
/// The rule *catalogue* remains the single source of truth for category
/// signals (urgency, account security, financial, prize, secrecy, authority,
/// promotion): a category is present when any catalogued rule in it matches.
class SignalFeatures {
  /// Categories with at least one matched catalogued rule.
  final Set<ThreatSignalCategory> categories;

  /// The message asks for a credential ("send your OTP", "enter your PIN").
  ///
  /// This is a *request* form, deliberately narrower than the `credential`
  /// rule: merely mentioning a password is not a request.
  final bool hasCredentialRequest;

  /// A high-confidence credential request (the code/token itself is asked for).
  final bool hasStrongCredentialRequest;

  /// The literal phrase that made [hasCredentialRequest] true, so the reason
  /// shown to the user quotes their own message.
  final String? credentialRequestSpan;

  /// The message's sentences, split once.
  ///
  /// Every phrase match that must stay within one sentence uses this, so the
  /// definition of a sentence boundary is identical everywhere.
  final List<String> sentences;

  /// A credential request that asks the reader to act on the secret itself
  /// (enter or provide a password, send a one-time code, restore access).
  final bool hasSevereCredentialRequest;

  /// The message asks for an action ("please provide your password") rather
  /// than describing one or warning against it ("never share your password").
  final bool hasImperativePasswordRequest;

  final bool hasAccountVerificationLanguage;
  final bool hasIdentityVerificationLanguage;

  /// Which catalogued rules matched, by id.
  final Set<String> matchedRuleIds;

  /// Whether a catalogued rule fired, by id.
  bool matched(String ruleId) => matchedRuleIds.contains(ruleId);

  const SignalFeatures({
    required this.categories,
    required this.matchedRuleIds,
    required this.hasCredentialRequest,
    required this.hasStrongCredentialRequest,
    this.hasSevereCredentialRequest = false,
    this.hasImperativePasswordRequest = false,
    this.credentialRequestSpan,
    this.sentences = const [],
    required this.hasAccountVerificationLanguage,
    required this.hasIdentityVerificationLanguage,
  });

  bool has(ThreatSignalCategory category) => categories.contains(category);

  bool get hasUrgency => has(ThreatSignalCategory.urgency);
  bool get hasAccountThreat => has(ThreatSignalCategory.accountSecurity);
  bool get hasCredentialSignal => has(ThreatSignalCategory.credential);
  bool get hasFinancialRequest => has(ThreatSignalCategory.financial);
  bool get hasPrizePattern => has(ThreatSignalCategory.prizeReward);
  bool get hasSecrecyPressure => has(ThreatSignalCategory.secrecy);
  bool get hasAuthorityReference => has(ThreatSignalCategory.authority);
  bool get hasPromotionalLanguage => has(ThreatSignalCategory.promotion);

  /// Extracts every shared signal from [text] exactly once.
  ///
  /// [text] should already be normalized (see `TextMatcher.normalize`); the
  /// matchers are case-insensitive and idempotent, so a caller that forgets
  /// still gets a correct answer, just slightly slower.
  factory SignalFeatures.extract(String text) {
    final categories = <ThreatSignalCategory>{};
    final matchedRuleIds = <String>{};

    for (final rule in ThreatRuleCatalog.rules) {
      if (TextMatcher.containsAny(text, rule.patterns)) {
        categories.add(rule.category);
        matchedRuleIds.add(rule.id);
      }
    }

    // A request must live inside one sentence. `containsAny` matches on the
    // normalized text, where sentences are joined by a single space, so
    // "attackers ask you to verify your account and enter your password" would
    // otherwise read as a literal "enter your password". Splitting first is
    // the difference between describing a request and making one.
    final sentences = _sentences(text).toList(growable: false);

    String? credentialRequestSpan;
    for (final sentence in sentences) {
      // A safety instruction is not a request: "Never share your OTP" contains
      // the words "share otp" but asks for nothing.
      final body = _safetyCommand.hasMatch(sentence.toLowerCase())
          ? sentence.replaceAll(_safetyCommand, '')
          : sentence;

      for (final phrase in credentialRequestPhrases) {
        final span = TextMatcher.firstMatch(body, phrase);
        if (span == null) continue;

        // A denied request is not a request: "banks will never ask you to
        // send your OTP". Scoped to the span's own clause, so a genuine
        // "do not reply to this text; send your OTP" still counts.
        if (_isNegatedBefore(body, span)) continue;

        credentialRequestSpan = span;
        break;
      }
      if (credentialRequestSpan != null) break;
    }

    final hasCredentialRequest = credentialRequestSpan != null;

    final hasStrongCredentialRequest = hasCredentialRequest &&
        sentences.any(
          (s) => TextMatcher.containsAny(s, strongCredentialRequestPhrases),
        );
    final hasSevereCredentialRequest = hasCredentialRequest &&
        sentences.any(
          (s) => TextMatcher.containsAny(s, strongCredentialActionPhrases),
        );

    return SignalFeatures(
      categories: Set.unmodifiable(categories),
      matchedRuleIds: Set.unmodifiable(matchedRuleIds),
      hasCredentialRequest: hasCredentialRequest,
      hasImperativePasswordRequest: isImperativePasswordRequest(
        text,
        hasCredentialRequest: hasCredentialRequest,
      ),
      hasStrongCredentialRequest: hasStrongCredentialRequest,
      hasSevereCredentialRequest: hasSevereCredentialRequest,
      credentialRequestSpan: credentialRequestSpan,
      sentences: sentences,
      hasAccountVerificationLanguage: TextMatcher.containsAny(
        text,
        accountVerificationPhrases,
      ),
      hasIdentityVerificationLanguage: TextMatcher.containsAny(
        text,
        identityVerificationPhrases,
      ),
    );
  }

  /// "Please provide your password" and "enter your password" are requests;
  /// "never share your password" is an advisory, and an advisory that also
  /// contains a request form is still a request.
  ///
  /// The advisory test is [isSafetyAdvice] — the same predicate the analyzer
  /// and the verdict policy use. It used to be a bare "does the text contain
  /// 'do not share' anywhere" check, which meant one advisory sentence at the
  /// end of a message re-enabled the "imperative request" reading for the
  /// whole message.
  static bool isImperativePasswordRequest(
    String text, {
    required bool hasCredentialRequest,
  }) {
    if (!hasCredentialRequest) return false;
    if (isSafetyAdvice(text)) return false;

    return TextMatcher.containsAny(text, const [
      'please provide your password',
      'please enter your password',
      'provide your password',
      'enter your password',
      'submit your password',
    ]);
  }

  /// Verb + possessive forms of "give us your secret".
  ///
  /// `verify your password` is deliberately absent: "we will never ask you to
  /// verify your password" is a fraud warning. `verify your identity` remains,
  /// because a message asking the reader to verify identity is itself the
  /// pattern.
  static const List<String> credentialRequestPhrases = [
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
    // Amount or account forms: a payment request, not a credential offer.
    'send money',
    'transfer money',
    'provide your bank account',
    'provide your bank details',
    'provide your account number',
    'send your account number',
    'provide your card details',
    'provide your card number',
    'provide your debit card',
    'provide your credit card',
  ];

  /// One-time codes and security tokens: the strongest request form, because
  /// no legitimate organisation ever asks the recipient to send one.
  static const List<String> strongCredentialRequestPhrases = [
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
  ];

  static const List<String> accountVerificationPhrases = [
    'verify your account',
    'verify account',
    'account verification',
    'confirm your account',
    'confirm account',
    'confirm your account details',
    'security verification',
  ];

  /// A phrase that precedes a safety instruction, inside one sentence:
  /// "Never share your OTP", "Do not click this link".
  static final RegExp _safetyCommand = RegExp(
    r'(?<![\p{L}\p{N}])(?:never|do not|don.t|must not|avoid)\s+(?:ever\s+)?'
    r'(?:share|give|send|tell|reply|click|provide|disclose|reveal|enter|do|'
    r'open|download|approve|scan|use)\b',
    unicode: true,
  );

  /// Sentences that *describe* a request rather than make one.
  ///
  /// "a message asking you to send your OTP", "we will never ask you to verify
  /// your account", "we received reports of a text telling people to click".
  /// Kept here, not in the verdict policy, so the analyzer, the feature
  /// extractor and the policy all skip the same spans — the policy used to have
  /// its own copy and the other two had none.
  static final RegExp _quotedLure = RegExp(
    r'\b(?:(?:ask(?:s|ing)?)|request(?:s|ing)?|tell(?:s|ing)?)\s+(?:you|people|'
    r'users|recipients|customers|them)\b|\breceive(?:d)?\s+(?:a|an|this|'
    r'these)\s+(?:message|sms|text|e-?mail|link)\b',
    unicode: true,
  );

  /// Whether [sentence] merely describes a request (see [_quotedLure]).
  static bool isQuotedContext(String sentence) =>
      _quotedLure.hasMatch(_stripDemands(sentence.toLowerCase()));

  /// A negation that precedes an *embedded* instruction: "banks will never
  /// ask you to send your OTP", "we will never request your password".
  ///
  /// Distinct from [_safetyCommand], where the negation is directly followed
  /// by the verb. Both are safety instructions, and both used to be missed by
  /// one predicate or the other: this form made a bank's own advisory read as
  /// a request.
  static final RegExp _negatedRequest = RegExp(
    r'\b(?:never|do not|don.t|will not|won.t|must not)\s+'
    r'(?:ever\s+)?(?:ask|request|need|require|contact|call|text)\b',
    unicode: true,
  );
  static bool isNegatedRequest(String sentence) =>
      _negatedRequest.hasMatch(sentence.toLowerCase());

  /// Any permanently negative scoping word.
  /// Any negative scoping word, used to decide that a request form inside the
  /// same clause is being denied rather than made.
  static final RegExp _negationScope = RegExp(
    r'(?<![\p{L}\p{N}])(?:never|do not|don.t|will not|won.t|must not|'
    r'cannot|can.t|no longer)\b',
    unicode: true,
  );

  /// Whether [sentence] contains a phrase that *requests* a credential.
  ///
  /// A phrase inside a safety instruction is not a request: "Never share your
  /// OTP" contains the words "share otp" but asks for nothing. The safety
  /// predicate is stripped before matching, which is what stops a bank's own
  /// fraud warning being scored as a phishing attempt.
  ///
  /// Kept here (rather than in the analyzer) so the feature extractor and the
  /// rule engine share one definition of "request".
  static String? requestSpan(String text) {
    for (final sentence in _sentences(text)) {
      // "banks will never ask you to send your OTP": the negation precedes the
      // quoted request, and `_stripDemands` removes it before matching.
      final body = _stripDemands(sentence.toLowerCase());

      for (final phrase in credentialRequestPhrases) {
        final span = TextMatcher.firstMatch(body, phrase);
        if (span == null) continue;
        if (_isNegatedBefore(body, span)) continue;
        return span;
      }
    }

    return null;
  }

  /// True when the clause containing [span] starts with a negation, i.e. the
  /// request is being denied rather than made.
  static bool _isNegatedBefore(String sentence, String span) {
    final at = sentence.indexOf(span);
    if (at < 0) return false;

    // Scope is the clause, not the sentence: a negation before the last
    // punctuation boundary does not reach this request.
    final start = sentence.lastIndexOf(RegExp(r'[.,;:]'), at) + 1;
    final clause = sentence.substring(start, at);

    return _negationScope.hasMatch(clause);
  }

  /// Removes instructions that *dispose* of a message rather than act on it.
  ///
  /// A fraud advisory says "if you receive a message asking you to verify your
  /// account, report it to your bank" — and that sentence also contains the
  /// quoted lure "send your otp" from the clause before it. Stripping the
  /// report/forward/delete instruction is what lets the advisory be recognised
  /// as an advisory; a real request never contains one.
  static String _stripDemands(String sentence) {
    var body = sentence;
    if (_safetyCommand.hasMatch(body)) {
      body = body.replaceAll(_safetyCommand, '');
    }
    if (_disposeCommand.hasMatch(body)) {
      body = body.replaceAll(_disposeCommand, '');
    }
    return body;
  }

  /// "report it to your bank", "forward the message to 7726", "just delete
  /// it", "block the sender". The verb is what matters, not the object.
  ///
  /// `\s*` rather than `\s+`: "report" alone at the end of a clause still
  /// counts, and that is enough to make a sentence an instruction.
  static final RegExp _disposeCommand = RegExp(
    r'(?<![\p{L}\p{N}])(?:report|forward|delete|block)\s*'
    r'(?:it|this|these|them|that|the|to|and)?',
    unicode: true,
  );

  /// Trimmed, case-folded text with runs of whitespace collapsed.
  ///
  /// Every phrase list here is matched with [TextMatcher.containsAny], which
  /// already normalizes, but the sentence-level checks below need their own
  /// splitting so a request cannot straddle a sentence boundary.
  static List<String> sentencesOf(String text) => splitSentences(text);

  /// The message's sentences, split once by the same boundary rule every
  /// detector uses.
  ///
  /// Public so the rule engine and the verdict policy stop re-deriving their
  /// own split: two different sentence boundaries produced two different
  /// answers to "is this request in the same sentence as that warning".
  static List<String> splitSentences(String text) {
    return text
        .split(RegExp(r'(?<=[.!?;])\s+|\n+'))
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  /// Whether [sentence] contains the shape of a safety instruction.
  ///
  /// Two forms, because advisories use both: a negation ("never share your
  /// OTP", "do not click") and a disposal instruction ("report it to your
  /// bank", "just delete it"). A real lure never tells the reader to report or
  /// delete anything.
  static bool hasSafetyCommand(String sentence) {
    final lower = sentence.toLowerCase();
    return _safetyCommand.hasMatch(lower) ||
        _disposeCommand.hasMatch(lower) ||
        _negatedRequest.hasMatch(lower);
  }

  /// Whether [text] offers a way to reach the sender that an attacker cannot
  /// copy. Used by the verdict policy to explain why a message that looks like
  /// pressure is really a notification.
  static bool isIndependentChannelCue(String text) =>
      TextMatcher.containsAny(text, independentChannelCues);

  /// The message names a way to reach the sender that an attacker cannot
  /// copy: the number on the back of the card, the official app, a branch.
  ///
  /// A genuine bank alert always offers one; a phishing message never does,
  /// because the whole point is to keep you inside *its* link. This is used
  /// only to *explain* a verdict — it never lowers a score or a level.
  static const List<String> independentChannelCues = [    'on the back of your card',
    'on the back of the card',
    'the number on your card',
    'official app',
    'official mobile app',
    'in the app',
    'through the app',
    'nearest branch',
    'visit a branch',
    'in person',
    'call us back',
    'from your phone',
  ];

  /// Whether [text] is *advice warning against* sharing a credential, rather
  /// than a request for one.
  ///
  /// Two independent conditions, because a phishing message happily uses the
  /// same vocabulary: a credential must be mentioned, and a safety command must
  /// appear in the same sentence as a credential word. It must also not contain
  /// an actual credential request — "do not share your OTP, send it to us" is
  /// still a request.
  static bool isSafetyAdvice(String text) {
    if (!TextMatcher.containsAny(text, _credentialWords)) return false;
    if (requestSpan(text) != null) return false;
    if (TextMatcher.containsAny(text, _credentialValuePatterns)) return false;

    for (final sentence in _sentences(text)) {
      final lower = sentence.toLowerCase();
      if (!_safetyCommand.hasMatch(lower) &&
          !_negatedRequest.hasMatch(lower) &&
          !_disposeCommand.hasMatch(lower)) {
        continue;
      }
      if (!TextMatcher.containsAny(sentence, _credentialWords)) continue;
      return true;
    }

    return false;
  }

  /// Phrases that make a *comment* about a credential into a claim about its
  /// value — "your OTP is 448201". A warning merely comments; a lure claims.
  static const List<String> _credentialValuePatterns = [
    'your otp is',
    'your pin is',
    'your code is',
    'otp is',
    'pin is',
    'verification code is',
    'security code is',
    'is your otp',
    'is your pin',
  ];

  static const List<String> _credentialWords = [
    'password',
    'otp',
    'pin',
    'passcode',
    'password',
    'login',
    'code',
    'credentials',
  ];

  static Iterable<String> _sentences(String text) => splitSentences(text);

  static const List<String> identityVerificationPhrases = [
    'verify your identity',
    'confirm your identity',
    'identity verification',
  ];

  /// Phrases that ask the reader to *act on authentication information* — enter
  /// it, confirm it, restore access with it, or continue with it. This is the
  /// "strong" request form used for severity: an OTP request is always severe.
  static const List<String> strongCredentialActionPhrases = [
    'provide your password',
    'enter your password',
    'submit your password',
    'confirm your password',
    'send your otp',
    'provide your otp',
    'enter your otp',
    'one-time password',
    'verification code',
    'security code',
    'restore access',
    'continue at',
  ];
}
