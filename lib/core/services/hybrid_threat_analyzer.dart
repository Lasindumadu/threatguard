import '../models/channel_profile.dart';
import '../models/hybrid_threat_analysis.dart';
import '../models/ml_feature_vector.dart';
import '../models/ml_prediction.dart';
import '../models/message_source.dart';
import '../models/protection_mode.dart';
import '../models/threat_analysis.dart';
import '../models/threat_signal.dart';
import 'ml_classifier.dart';
import 'ml_feature_encoder.dart';
import 'ml_feature_extractor.dart';
import 'signal_features.dart';
import 'threat_analyzer.dart';
import 'verdict_policy.dart';

/// Reconciles the rule engine and the statistical classifier into one verdict.
///
/// The arbitration policy is deliberately conservative and explicit, because
/// "which engine won" is the difference between a defensible product and an
/// unexplainable number:
///
///  * **Consensus** — both engines name the same class. Use it.
///  * **Rules silent** — accept the model, but only above [mlOverrideThreshold].
///  * **Model says legitimate** — only clear a *weak* rule hit, and only when
///    the model is extremely sure ([mlDowngradeThreshold]).
///  * **Both say threat, different class** — strong rule evidence wins; a
///    low-margin model never overrides hard evidence.
class HybridThreatAnalyzer {
  final ThreatAnalyzer threatAnalyzer;
  final MlFeatureExtractor featureExtractor;
  final MlFeatureEncoder featureEncoder;
  final MlClassifier classifier;

  const HybridThreatAnalyzer({
    this.threatAnalyzer = const ThreatAnalyzer(),
    this.featureExtractor = const MlFeatureExtractor(),
    this.featureEncoder = const MlFeatureEncoder(),
    required this.classifier,
  });

  // Defaults, kept for backwards compatibility with existing callers and
  // tests. A [ProtectionMode] overrides each of these at analysis time.
  static const double mlOverrideThreshold = 0.75;
  static const double mlDowngradeThreshold = 0.90;
  static const int strongRuleScore = 50;
  static const int weakRuleScore = 30;

  /// Minimum top-vs-runner-up gap for the model to be considered "decisive".
  /// A model that cannot separate phishing from scam should not arbitrate.
  static const double minDecisiveMargin = 0.05;

  HybridThreatAnalysis analyze(String message, {
    ProtectionMode mode = ProtectionMode.balanced,
    MessageSource source = MessageSource.manual,
  }) {
    // The mode is passed down, not just recorded: it sets the rule engine's
    // suspicious floor, the arbitration thresholds, and whether the channel
    // contributes risk.
    final ruleAnalysis = threatAnalyzer.analyze(message, mode: mode);

    final features = featureExtractor.extract(message: message);
    final encodedFeatures = featureEncoder.encode(features);

    final MlPrediction mlPrediction;
    try {
      mlPrediction = classifier.predict(encodedFeatures);
    } catch (_) {
      // A model that cannot score this message must not take the UI down, and
      // must not be reported as "safe". Fall back to the rule verdict alone and
      // say so in the rationale.
      return VerdictPolicy.assemble(
        ruleAnalysis: ruleAnalysis,
        mlPrediction: const MlPrediction(
          type: MlThreatType.legitimate,
          confidence: 0,
        ),
        finalType: ruleAnalysis.type,
        source: ruleAnalysis.type == ThreatType.legitimate
            ? VerdictSource.none
            : VerdictSource.ruleEngine,
        rationale:
            'The model could not score this message, so the verdict rests on '
            'rule evidence alone.',
        mode: mode,
        channel: ChannelProfile.of(source),
      );
    }

    final decision = _resolveFinalType(
      ruleAnalysis: ruleAnalysis,
      ml: mlPrediction,
      mode: mode,
    );

    final mlType = _toThreatType(mlPrediction.type);
    final agreement = _agreement(
      ruleType: ruleAnalysis.type,
      mlType: mlType,
      mlConfidence: mlPrediction.confidence,
    );

    final channel = ChannelProfile.of(source);

    final benignReason = VerdictPolicy.benignContext(
      message,
      SignalFeatures.extract(message),
    );

    return VerdictPolicy.assemble(
      ruleAnalysis: ruleAnalysis,
      mlPrediction: mlPrediction,
      finalType: decision.type,
      source: decision.source,
      rationale: decision.rationale,
      mode: mode,
      // One owner for "does the channel contribute risk": the mode. Before
      // this, Relaxed skipped the bonus here and every other mode applied it,
      // while [ProtectionMode.applyChannelRisk] — the value the Shield panel
      // displays — was only read by a helper nothing called.
      channel: mode.applyChannelRisk ? channel : null,
      benignReason: benignReason,
      // "Offer", "selected customers" and "discount" are marketing cues, not
      // evidence of anything: a recruitment message that says "offer" must not
      // be spam, and a marketing message that contains no request is only spam.
      promotional: ruleAnalysis.type == ThreatType.spam &&
          !ruleAnalysis.indicators.any(
            (i) =>
                i.category == ThreatSignalCategory.prizeReward ||
                i.category == ThreatSignalCategory.financial ||
                i.category == ThreatSignalCategory.credential,
          ) &&
          VerdictPolicy.isMarketingOnly(message),
      agreement: agreement,
    );
  }

  /// Extra risk contributed by the channel, applied only when the message
  /// actually carries a link — the shape of a real messaging attack.
  ///
  /// Ownership note: this is computed by [VerdictPolicy.assemble], which is the
  /// only place a `channelRiskBonus` is assigned. It is kept here only so the
  /// documented constant stays next to the analyzer that uses it.
  static int channelBonus({
    required ChannelProfile channel,
    required ProtectionMode mode,
    required bool hasUrl,
  }) {
    if (!hasUrl || !mode.applyChannelRisk) return 0;
    return channel.urlRiskBonus;
  }

  _Verdict _resolveFinalType({
    required ThreatAnalysis ruleAnalysis,
    required MlPrediction ml,
    required ProtectionMode mode,
  }) {
    final ruleType = ruleAnalysis.type;
    final mlType = _toThreatType(ml.type);
    final score = ruleAnalysis.riskScore;
    final decisive = ml.margin >= minDecisiveMargin;

    final mlOverride = mode.mlOverrideThreshold;
    final mlDowngrade = mode.mlDowngradeThreshold;
    final strongScore = mode.strongRuleScore;
    final weakScore = mode.weakRuleScore;

    // The model may only *clear* a rule hit when it is both sure and able to
    // tell its classes apart. Confidence alone used to be enough here, while
    // the "rules found nothing" branch already demanded a decisive margin —
    // so a model that spread 0.91/0.45/… across two classes could silence rule
    // evidence it could not actually classify. `weakRuleScore < strongRuleScore`
    // in every mode, which is what makes the weak branch reachable.
    final canClear = ml.margin >= minDecisiveMargin;

    // Both systems agree.
    if (ruleType == mlType) {
      return _Verdict(
        ruleType,
        VerdictSource.consensus,
        'Both the rule engine and the machine-learning model classified this '
            'message as ${ruleType.name}.',
      );
    }

    // Rules found nothing: accept the ML only when sufficiently confident
    // *and* decisive about which class it is.
    if (ruleType == ThreatType.legitimate) {
      if (ml.confidence >= mlOverride && decisive) {
        return _Verdict(
          mlType,
          VerdictSource.machineLearning,
          'No rule fired, but the model detected ${mlType.name} features with '
              '${_percent(ml.confidence)} confidence.',
        );
      }

      return _Verdict(
        ThreatType.legitimate,
        VerdictSource.none,
        ml.confidence >= mlOverride
            ? 'The model leaned towards ${mlType.name}, but its probabilities '
                  'were too close to call, so no threat was confirmed.'
            : 'No meaningful rule or model signal was found.',
      );
    }

    // Rules found a threat, but ML says legitimate.
    // Only clear weak rule hits with very high ML confidence.
    if (mlType == ThreatType.legitimate) {
      final clear =
          canClear &&
          score < weakScore &&
          ruleAnalysis.level != ThreatLevel.highRisk &&
          ml.confidence >= mlDowngrade;

      if (clear) {
        return _Verdict(
          ThreatType.legitimate,
          VerdictSource.modelOverride,
          'Weak rule indicators (score $score/100) were overruled by a '
              '${_percent(ml.confidence)} legitimate verdict from the model.',
        );
      }

      if (!canClear &&
          score < weakScore &&
          ruleAnalysis.level != ThreatLevel.highRisk &&
          ml.confidence >= mlDowngrade) {
        // The safety-critical case: the model wanted to clear a weak rule hit
        // but could not separate its own classes, so the rule verdict stands.
        // Saying so is the difference between "the model disagreed" and "we
        // kept the finding because the model was not able to arbitrate".
        return _Verdict(
          ruleType,
          VerdictSource.ruleEngine,
          'The model leaned towards legitimate (${_percent(ml.confidence)}) '
              'but its top two classes were too close to call, so the weak rule '
              'evidence (score $score/100) stands.',
        );
      }

      return _Verdict(
        ruleType,
        VerdictSource.ruleEngine,
        'The rule engine found ${ruleType.name} evidence (score $score/100) '
            'that the model did not outweigh.',
      );
    }

    // Both systems detect a threat but disagree on its category.
    // Strong rule evidence wins; otherwise a sufficiently confident and
    // decisive model may reclassify.
    if (score >= strongScore) {
      return _Verdict(
        ruleType,
        VerdictSource.ruleEngine,
        'Strong rule evidence (score $score/100) placed this in the '
            '${ruleType.name} category ahead of the model\'s ${mlType.name} '
            'guess.',
      );
    }

    if (ml.confidence >= mlOverride && decisive) {
      return _Verdict(
        mlType,
        VerdictSource.machineLearning,
        'Engines disagreed; the model\'s ${mlType.name} verdict '
            '(${_percent(ml.confidence)}) was decisive over weaker rule '
            'evidence.',
      );
    }

    return _Verdict(
      ruleType,
      VerdictSource.ruleEngine,
      'Engines disagreed; the model was not decisive enough to override the '
          'rule engine\'s ${ruleType.name} finding.',
    );
  }

  /// Agreement score: 1.0 when both engines name the same class, decaying with
  /// the model's confidence the further apart the two verdicts are.
  double _agreement({
    required ThreatType ruleType,
    required ThreatType mlType,
    required double mlConfidence,
  }) {
    if (ruleType == mlType) return 1.0;

    return (1.0 - mlConfidence).clamp(0.0, 1.0);
  }

  ThreatType _toThreatType(MlThreatType type) {
    switch (type) {
      case MlThreatType.legitimate:
        return ThreatType.legitimate;
      case MlThreatType.spam:
        return ThreatType.spam;
      case MlThreatType.phishing:
        return ThreatType.phishing;
      case MlThreatType.scam:
        return ThreatType.scam;
      case MlThreatType.socialEngineering:
        return ThreatType.socialEngineering;
    }
  }

  static String _percent(double value) =>
      '${(value * 100).toStringAsFixed(1)}%';
}

class _Verdict {
  final ThreatType type;
  final VerdictSource source;
  final String rationale;

  const _Verdict(this.type, this.source, this.rationale);
}
