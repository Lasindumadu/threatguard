import 'protection_mode.dart';
import 'threat_signal.dart';

enum ThreatLevel { safe, suspicious, highRisk, critical }

enum ThreatType { legitimate, spam, phishing, scam, socialEngineering }

/// How much a single piece of evidence actually establishes.
///
/// The distinction is the difference between a defensible product and one that
/// cries wolf. A message asking for an OTP is *observed*: that text is either
/// there or it is not. A lookalike domain is *inferred*: strong, but it is a
/// judgement about intent made from structure. Whether the sender really is the
/// organisation it claims is *unknown*, because ThreatGuard cannot verify
/// sender identity (see `SenderVerificationStatus`).
enum EvidenceProvenance {
  /// Directly observed in the input, with no interpretation.
  observed,

  /// A pattern-based inference from structure or wording; can be wrong.
  inferred,

  /// Not established by this evidence — reported instead of implied.
  unknown,
}

class ThreatIndicator {
  final String title;
  final String description;
  final int scoreContribution;

  /// The literal text that triggered this indicator, when there is one.
  /// Surfaced in the UI so a user can see exactly what matched.
  final String? evidence;

  /// Which family of manipulation technique this indicator belongs to.
  final ThreatSignalCategory? category;

  /// What this evidence establishes. Defaults to [EvidenceProvenance.inferred]
  /// because that is the honest default for pattern matching.
  final EvidenceProvenance provenance;

  /// Stable identity used to de-duplicate evidence, e.g. `rule:financial` or
  /// `url:http://bit.ly/x:urlShortener`.
  ///
  /// Two rules that match the same span are still two different reasons, so the
  /// key includes the reason — but the same reason can never be counted twice,
  /// whichever engine found it.
  final String? dedupeKey;

  const ThreatIndicator({
    required this.title,
    required this.description,
    required this.scoreContribution,
    this.evidence,
    this.category,
    this.provenance = EvidenceProvenance.inferred,
    this.dedupeKey,
  });

  /// Key a collection can use to drop repeats. Falls back to title+evidence,
  /// which is unique for every indicator this app emits.
  String get identity => dedupeKey ?? '$title|${evidence ?? ''}';
}

/// How strongly the *evidence* supports the verdict, as distinct from how
/// dangerous the message might be.
///
/// Phase 1 finding: the taxonomy had `ThreatLevel` (how loudly to warn) and
/// `ThreatType` (what kind of thing it looks like), but no way to say *"how
/// sure are we that this is actually an attack"*. A model-only call and a
/// message-plus-phishing-link-plus-credential-request both surfaced as
/// "highRisk", which reads as confirmation in the first case and understates
/// the second.
///
/// Nothing on-device can reach [confirmedThreat]: confirming an attack needs
/// something the app does not have (a takedown list, sender authentication, or
/// the user's own report). It exists so the scale is explicit and the UI can
/// say "we never say confirmed".
enum EvidenceConfidence {
  /// Nothing matched, or the evidence is contradicted by benign context.
  benign,

  /// Weak or conflicting signals. Worth a look, not worth alarm.
  suspicious,

  /// A coherent attack shape, or a model call that could not be arbitrated
  /// away. Strong, still inferential.
  highRisk,

  /// Reserved for evidence this app cannot obtain. Never set by on-device
  /// analysis; present so no caller mistakes "highRisk" for "confirmed".
  confirmedThreat,
}

class ThreatAnalysis {
  /// 0–100 additive **risk index**, not a probability. See
  /// [HybridThreatAnalysis.blendedRiskScore] for how it is blended.
  final int riskScore;
  final ThreatLevel level;
  final ThreatType type;
  final List<ThreatIndicator> indicators;
  final List<String> detectedUrls;
  final String summary;
  final String recommendation;

  /// How many duplicate evidence rows were collapsed before scoring.
  /// Exposed so the UI can explain the number instead of quietly trimming it.
  final int evidenceDuplicatesRemoved;

  /// True when the input exceeded `ThreatAnalyzer.maxMessageLength` and only
  /// the leading part was analysed. The UI must say this rather than imply the
  /// whole message was read.
  final bool wasTruncated;

  /// The protection mode this analysis was produced under. Carrying it on the
  /// result (rather than only on the blended analysis) makes a stored verdict
  /// self-describing.
  final ProtectionMode mode;

  /// Wording that makes the message look genuine — a completed transaction, a
  /// tracking reference, a safety warning. Computed once here so the UI never
  /// has to re-derive it (and never disagrees with the verdict).
  final List<String> supportingEvidence;

  /// The risk score *before* any level override (benign context, model-only
  /// floor). Kept so the UI can explain "the rules scored 41, but this reads
  /// like a bank alert, so it was not treated as an attack". Null when the
  /// caller did not track one.
  final int? rawRiskScore;

  /// Distinct reasons that actually added points, highest contribution first.
  ///
  /// This is the answer to "what made you say that": additions from
  /// contextual escalation are appended as "why" notes with a null score.
  final List<ThreatIndicator> scoredEvidence;

  const ThreatAnalysis({
    required this.riskScore,
    required this.level,
    required this.type,
    required this.indicators,
    required this.detectedUrls,
    required this.summary,
    required this.recommendation,
    this.evidenceDuplicatesRemoved = 0,
    this.wasTruncated = false,
    this.mode = ProtectionMode.balanced,
    this.supportingEvidence = const [],
    this.rawRiskScore = 0,
    this.scoredEvidence = const [],
  });

  /// The evidence-driven confidence, derived from level and type.
  ///
  /// Deliberately conservative: a spam-labelled, suspicious-level message is
  /// never above [EvidenceConfidence.suspicious], because "unwanted" is not
  /// "dangerous".
  EvidenceConfidence get evidenceConfidence {
    if (level == ThreatLevel.safe || type == ThreatType.legitimate) {
      return EvidenceConfidence.benign;
    }
    if (level == ThreatLevel.suspicious) return EvidenceConfidence.suspicious;
    // "High risk" is a warning level, not a finding. Unwanted mail (spam) would
    // otherwise reach `highRisk` on the strength of a marketing phrase, and
    // even a real threat is only *inferred* from wording and structure.
    // `confirmedThreat` stays unreachable on device.
    return EvidenceConfidence.highRisk;
  }

  /// Copy with a new level/type, preserving every other field.
  ///
  /// Used instead of re-constructing the object at each call site: a manual
  /// reconstruction is exactly how `supportingEvidence` was silently dropped
  /// from a downgraded verdict.
  ThreatAnalysis copyWith({
    int? riskScore,
    ThreatLevel? level,
    ThreatType? type,
    String? summary,
    String? recommendation,
  }) {
    return ThreatAnalysis(
      riskScore: riskScore ?? this.riskScore,
      level: level ?? this.level,
      type: type ?? this.type,
      indicators: indicators,
      detectedUrls: detectedUrls,
      summary: summary ?? this.summary,
      recommendation: recommendation ?? this.recommendation,
      evidenceDuplicatesRemoved: evidenceDuplicatesRemoved,
      wasTruncated: wasTruncated,
      mode: mode,
      supportingEvidence: supportingEvidence,
      rawRiskScore: rawRiskScore,
      scoredEvidence: scoredEvidence,
    );
  }
}
