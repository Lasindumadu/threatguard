import 'ml_feature_vector.dart';
import 'channel_profile.dart';
import 'ml_prediction.dart';
import 'protection_mode.dart';
import 'threat_analysis.dart';
import '../services/threat_analyzer.dart';
/// How the final verdict was reached. This is the audit trail reviewers
/// (and users) need in order to trust a classification.
enum VerdictSource {
  /// Rule engine and ML agreed.
  consensus,

  /// Rules found nothing meaningful; the ML model supplied the verdict.
  machineLearning,

  /// Rule evidence was strong enough to override a dissenting model.
  ruleEngine,

  /// Rules detected a threat; the model cleared a weak rule hit.
  modelOverride,

  /// A trusted external source reported this message or its link as malicious.
  /// The only source that can produce a confirmation.
  externalReport,

  /// Nothing fired at all.
  none,
}

/// The reconciled result of running every detection engine over one message.
class HybridThreatAnalysis {
  final ThreatAnalysis ruleAnalysis;
  final MlPrediction mlPrediction;
  final ThreatType finalType;

  /// Which engine was decisive, and why.
  final VerdictSource source;
  final String rationale;

  /// 0..1 — how much the two engines agree with each other.
  final double agreement;

  /// Which protection mode produced this verdict.
  final ProtectionMode protectionMode;

  /// The channel the message arrived through.
  final ChannelProfile? channel;

  /// Extra risk points contributed by the channel (unsolicited-messenger link).
  final int channelRiskBonus;

  /// Set when the analysis could not run and a safe placeholder is returned.
  /// The UI shows this as "not analysed", never as "safe".
  final String? unavailableReason;

  /// Evidence level supplied by a trusted external source.
  ///
  /// Null for every on-device analysis. This is deliberately *not* a settable
  /// "confidence" field: only [VerdictPolicy.confirmedByExternalReport] passes
  /// one, so a heuristic score can never be promoted to a confirmation by
  /// changing a number.
  final EvidenceConfidence? confirmedEvidence;

  const HybridThreatAnalysis({
    required this.ruleAnalysis,
    required this.mlPrediction,
    required this.finalType,
    this.source = VerdictSource.none,
    this.rationale = '',
    this.agreement = 0.0,
    this.protectionMode = ProtectionMode.balanced,
    this.channel,
    this.channelRiskBonus = 0,
    this.unavailableReason,
    this.confirmedEvidence,
  });

  /// True when nothing was actually analysed (disabled channel, engine
  /// failure). A safe-looking placeholder is not a verdict.
  bool get isAnalysed => unavailableReason == null;

  ThreatLevel get finalLevel {
    if (unavailableReason != null) {
      return ThreatLevel.safe;
    }

    if (finalType == ThreatType.legitimate) {
      return ThreatLevel.safe;
    }

    if (ruleAnalysis.type == ThreatType.legitimate) {
      return ThreatLevel.suspicious;
    }

    return ruleAnalysis.level;
  }

  bool get isThreat => finalType != ThreatType.legitimate;

  /// How confident the verdict is that this is *evidence of an attack*, as
  /// opposed to how much risk to communicate.
  ///
  /// A model-only call is never more than [EvidenceConfidence.highRisk], and a
  /// disabled channel or engine failure is [EvidenceConfidence.benign] with
  /// [isAnalysed] false — "not checked" must never read as "checked and fine".
  EvidenceConfidence get evidenceConfidence {
    if (unavailableReason != null) return EvidenceConfidence.benign;

    // A threat verdict backed by an external report is the one case that may
    // say "confirmed". It is checked before the heuristic scale, because the
    // heuristic scale can only ever *lower* it, never raise itself to it.
    if (isThreat && source == VerdictSource.externalReport) {
      return confirmedEvidence ?? EvidenceConfidence.highRisk;
    }

    final rule = finalLevel == ThreatLevel.safe
        ? EvidenceConfidence.benign
        : ruleAnalysis.evidenceConfidence;

    // A model-only verdict on a rule-silent message is `suspicious` at most:
    // the rule engine found no evidence, so nothing is confirmed.
    if (ruleAnalysis.type == ThreatType.legitimate && isThreat) {
      return EvidenceConfidence.suspicious;
    }

    // An explicit model override to "legitimate" cannot leave threat evidence
    // behind in the confidence.
    if (!isThreat) return EvidenceConfidence.benign;

    return rule;
  }

  /// Whether a *trusted external source* confirmed this message as malicious.
  ///
  /// A high heuristic score is not confirmation. Phrase matching, link
  /// structure and a logistic regression are all inferences, so they can never
  /// reach [EvidenceConfidence.confirmedThreat] — that value is only carried on
  /// a verdict produced by the external-report path
  /// (`VerdictPolicy.confirmedByExternalReport`), which no on-device analysis
  /// calls. Kept as a named predicate so the rule is stated in code, not left
  /// to an accident of the scale.
  bool get isConfirmedThreat => evidenceConfidence == EvidenceConfidence.confirmedThreat;

  /// The explanation for this exact verdict.
  ///
  /// The rule engine's summary is computed from the rule verdict alone. When
  /// the final category or level differs (a model-only call, a benign-context
  /// downgrade, Strict's category-less "suspicious"), showing it made the
  /// screen contradict itself: "Suspicious" above "No major threat indicators
  /// were detected." Derived from the final verdict, using the same wording,
  /// so a stored or displayed result always explains what it actually says.
  String get summary {
    if (unavailableReason != null) return unavailableReason!;

    final level = finalLevel;

    if (level == ThreatLevel.safe || finalType == ThreatType.legitimate) {
      return ruleAnalysis.summary;
    }

    return ThreatAnalyzer.describeSummary(finalType, level);
  }

  /// A single 0..100 **risk index** that blends rule evidence with model
  /// confidence.
  ///
  /// This is not a calibrated probability of malice, and the UI must never
  /// present it as one. It is a bounded heuristic: the rule score alone
  /// under-reports machine-only detections (it can be 0 while the model is
  /// sure), and model confidence alone ignores hard evidence. The blend never
  /// drops below the rule score, so hard evidence is never diluted away.
  int get blendedRiskScore {
    final ruleScore = ruleAnalysis.riskScore;

    final mlPositive = mlPrediction.type != MlThreatType.legitimate;
    final mlScore = mlPositive ? (mlPrediction.confidence * 100).round() : 0;

    if (!isThreat) {
      // Legitimate verdicts keep a small residual signal so "safe at 12/100"
      // is visible rather than being flattened to zero.
      return (ruleScore + channelRiskBonus).clamp(0, 100);
    }

    final blended = ((ruleScore * 0.6) + (mlScore * 0.4)).round();
    final withChannel = blended + channelRiskBonus;

    final floor = withChannel < ruleScore ? ruleScore : withChannel;
    return floor.clamp(0, 100);
  }

  /// How much confidence this verdict is entitled to, given how the evidence
  /// was obtained and whether the engines agreed.
  ///
  /// Deliberately capped well below 1.0: nothing ThreatGuard can observe
  /// *confirms* an attack. A user who already gave away a code, or a mail
  /// server that was real but compromised, both defeat any on-device
  /// classifier, so the honest ceiling is "high confidence", never "certain".
  double get verdictConfidence {
    if (unavailableReason != null) return 0.0;

    // A benign verdict carries no *threat* certainty: "we found nothing" is a
    // statement about the absence of evidence, not about safety.
    if (!isThreat) return 0.0;

    final ruleCertainty = switch (ruleAnalysis.level) {
      ThreatLevel.highRisk => 0.90,
      ThreatLevel.suspicious => 0.70,
      ThreatLevel.safe => 0.60,
    };

    if (source == VerdictSource.none) return ruleCertainty * 0.8;
    if (source == VerdictSource.machineLearning) {
      // The model's own number is a class probability, not a calibrated
      // probability of malice; it is scaled down and capped.
      return (mlPrediction.confidence * 0.85).clamp(0.0, 0.85);
    }

    // Rules decided, alone or with the model behind them. Where the engines
    // disagree the verdict is weaker, and disagreement is measured, not
    // asserted. A model override that cleared a weak rule hit is deliberately
    // not treated as a threat verdict here: the final type is legitimate, so
    // the `isThreat` guard above already returned 0.
    return (ruleCertainty * (0.75 + 0.25 * agreement)).clamp(0.0, 0.95);
  }

  /// What can be *stated* about this message, as opposed to inferred.
  ///
  /// Each line is written in the language the evidence supports: observed
  /// facts are stated plainly, structural inferences are hedged, and anything
  /// the app cannot know (sender identity, ownership, intent) is listed as
  /// unknown rather than guessed. This is what the detail screen renders under
  /// "What we know / inferred / don't know".
  EvidenceSummary get evidenceSummary {
    return evidenceSummaryWithSender();
  }

  /// [evidenceSummary] plus whatever is known *about the sender*.
  ///
  /// The sender block is deliberately narrow. The app can read the sender
  /// field and compare a short code with its registry; it cannot verify that
  /// "HNB" is the bank, that a number belongs to a business, or who owns a
  /// domain. Those go under "unknown" rather than being implied.
  EvidenceSummary evidenceSummaryWithSender({
    bool senderShortCodeUnregistered = false,
    String? sender,
  }) {
    if (unavailableReason != null) {
      return EvidenceSummary(
        known: const [],
        supports: const [],
        inferred: const [],
        unknown: [unavailableReason!],
      );
    }

    final known = <String>[
      for (final indicator in ruleAnalysis.indicators)
        if (indicator.provenance == EvidenceProvenance.observed)
          indicator.evidence == null || indicator.evidence!.isEmpty
              ? indicator.title
              : '${indicator.title} — the message contains "${indicator.evidence}"',
    ];
    final inferred = <String>[
      for (final indicator in ruleAnalysis.indicators)
        if (indicator.provenance == EvidenceProvenance.inferred)
          indicator.title,
    ];
    final unknown = <String>[];

    if (ruleAnalysis.detectedUrls.isNotEmpty) {
      known.add(
        '${ruleAnalysis.detectedUrls.length} link'
        '${ruleAnalysis.detectedUrls.length == 1 ? '' : 's'} in the message',
      );
    }

    unknown.add('Whether the sender is really who the message claims');
    unknown.add(
      'What happens after a link is opened (ThreatGuard does not visit links)',
    );

    if (senderShortCodeUnregistered) {
      // A fact, not a verdict: an unlisted short code is worth noticing, but
      // the registry is hand-maintained and cannot be a complete list.
      unknown.add(
        'How to reach the organisation behind the short code '
        '${sender ?? ''} — it is not in the registry this app checks against',
      );
    }

    if (source == VerdictSource.machineLearning ||
        source == VerdictSource.modelOverride) {
      unknown.add(
        'Whether this sender has targeted you before — a single message cannot '
            'show a campaign',
      );
    }

    if (ruleAnalysis.wasTruncated) {
      unknown.add(
        'The end of a very long message, which was not analysed',
      );
    }

    return EvidenceSummary(
      known: List.unmodifiable(known.toSet()),
      supports: List.unmodifiable(ruleAnalysis.supportingEvidence),
      inferred: List.unmodifiable(inferred.toSet()),
      unknown: List.unmodifiable(unknown.toSet()),
    );
  }

  /// Copy with a replacement level for the rule analysis, used by the verdict
  /// policy when a benign context is detected.
  HybridThreatAnalysis withRuleLevel(
    ThreatLevel level, {
    required ThreatType type,
  }) {
    return HybridThreatAnalysis(
      ruleAnalysis: ruleAnalysis.copyWith(level: level, type: type),
      mlPrediction: mlPrediction,
      finalType: type,
      source: source,
      rationale: rationale,
      agreement: agreement,
      protectionMode: protectionMode,
      channel: channel,
      channelRiskBonus: channelRiskBonus,
      unavailableReason: unavailableReason,
    );
  }
}

/// The known / inferred / unknown split of what a verdict rests on.
class EvidenceSummary {
  final List<String> known;

  /// Wording that points the other way: facts that make a message look
  /// genuine. Shown separately so "suspicious" never hides its counter-
  /// evidence.
  final List<String> supports;

  final List<String> inferred;
  final List<String> unknown;

  const EvidenceSummary({
    required this.known,
    required this.inferred,
    required this.unknown,
    this.supports = const [],
  });
}
