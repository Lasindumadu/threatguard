import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/hybrid_threat_analysis.dart';
import 'package:threatguard/core/models/ml_feature_vector.dart';
import 'package:threatguard/core/models/ml_prediction.dart';
import 'package:threatguard/core/models/protection_mode.dart';
import 'package:threatguard/core/models/threat_analysis.dart';
import 'package:threatguard/core/models/threat_message.dart';
import 'package:threatguard/core/models/message_source.dart';
import 'package:threatguard/core/services/app_services.dart';
import 'package:threatguard/core/services/hybrid_threat_analyzer.dart';
import 'package:threatguard/core/services/ml_classifier.dart';
import 'package:threatguard/core/services/threat_analyzer.dart';
import 'package:threatguard/core/services/threat_engine.dart';

/// A classifier with a fixed verdict and confidence, so the arbitration
/// thresholds can be exercised without depending on whatever the trained model
/// currently believes about a sentence.
class _FixedClassifier implements MlClassifier {
  const _FixedClassifier(this.type, this.confidence);

  final MlThreatType type;
  final double confidence;

  @override
  MlPrediction predict(List<double> features) {
    final probabilities = List<double>.filled(MlThreatType.values.length, 0);
    probabilities[MlThreatType.values.indexOf(type)] = confidence;
    final rest = (1 - confidence) / (MlThreatType.values.length - 1);
    for (var i = 0; i < probabilities.length; i++) {
      if (i != 0) probabilities[i] = rest;
    }

    return MlPrediction(
      type: type,
      confidence: confidence,
      probabilities: probabilities,
    );
  }
}

/// Legitimate at 0.95, but only 0.02 ahead of spam: confident, not decisive.
class _AmbiguousClassifier implements MlClassifier {
  const _AmbiguousClassifier();

  @override
  MlPrediction predict(List<double> features) => const MlPrediction(
    type: MlThreatType.legitimate,
    confidence: 0.95,
    probabilities: [0.50, 0.48, 0.01, 0.005, 0.005],
  );
}

/// A fresh engine per test: the process-wide instance shares one cache, and a
/// mode switch must not be observable through another test's entry.
ThreatEngine _engine() {
  final services = AppServices.instance;
  return ThreatEngine(
    analyzer: services.threatEngine.analyzer,
    senderAnalyzer: services.threatEngine.senderAnalyzer,
    organizationUrlAnalyzer: services.threatEngine.organizationUrlAnalyzer,
    fingerprintMatcher: services.threatEngine.fingerprintMatcher,
    urlReputationProvider: services.threatEngine.urlReputationProvider,
  );
}

void main() {
  // 18/100: the account-warning vocabulary fires, but nothing asks for a
  // credential, money or a link. Above Strict's floor (15), below Balanced's
  // (25) and Relaxed's (30).
  const weakSignal = 'We noticed a security alert on your account.';

  // Rules: prize-only spam at 22/100. Below every mode's `weakRuleScore`
  // (30/25/25 on balanced/strict/relaxed) and not high risk, so a sure model
  // is allowed to clear it — which is the branch the mode threshold governs.
  const spamSignal = 'Congratulations, you are a winner!';

  group('default mode', () {
    test('a fresh engine starts balanced and behaves like it', () {
      final engine = _engine();

      expect(engine.mode, ProtectionMode.balanced);
      expect(
        ProtectionMode.balanced.suspiciousScoreFloor,
        25,
        reason: 'the default floor the Shield tab documents',
      );

      expect(
        engine.analyzeText(weakSignal).analysis.finalLevel,
        ThreatLevel.safe,
        reason: 'below the balanced floor; the default must not alert',
      );
    });

    test('ProtectionMode defaults to balanced everywhere it is defaulted', () {
      // Engine constructor default.
      final engine = ThreatEngine(
        analyzer: AppServices.instance.threatEngine.analyzer,
        senderAnalyzer: AppServices.instance.threatEngine.senderAnalyzer,
        organizationUrlAnalyzer:
            AppServices.instance.threatEngine.organizationUrlAnalyzer,
        fingerprintMatcher:
            AppServices.instance.threatEngine.fingerprintMatcher,
        urlReputationProvider:
            AppServices.instance.threatEngine.urlReputationProvider,
      );
      expect(engine.mode, ProtectionMode.balanced);

      // Rule engine default.
      expect(
        const ThreatAnalyzer().analyze(weakSignal).level,
        ThreatLevel.safe,
      );
    });
  });

  group('strict mode', () {
    test('surfaces a weak signal that balanced keeps safe', () {
      final strict = _engine().analyzeText(
        weakSignal,
        mode: ProtectionMode.strict,
      );

      expect(strict.analysis.protectionMode, ProtectionMode.strict);
      expect(
        strict.analysis.finalLevel,
        ThreatLevel.suspicious,
        reason:
            'strict floor is 15 and the message scores 18; balanced (25) '
            'keeps the same message safe',
      );
      expect(strict.analysis.ruleAnalysis.mode, ProtectionMode.strict);
    });

    test('does not turn an uncertain message into a confirmed scam', () {
      final strict = _engine().analyzeText(
        weakSignal,
        mode: ProtectionMode.strict,
      );

      // The mode raises *attention*, never certainty and never a scam label.
      expect(strict.analysis.finalLevel, isNot(ThreatLevel.highRisk));
      expect(strict.analysis.finalType, isNot(ThreatType.scam));
      expect(strict.analysis.isConfirmedThreat, isFalse);
      expect(
        strict.analysis.evidenceConfidence,
        isNot(EvidenceConfidence.confirmedThreat),
      );
      expect(
        strict.analysis.verdictConfidence,
        lessThan(0.95),
        reason: 'a weak signal is never a confident verdict',
      );
      // The existing architecture keeps the category the facts support (here
      // the urgency/account vocabulary falls back to spam), and expresses the
      // uncertainty through the *level* and the absence of confirmation — not
      // by inventing a scam, and not by erasing the category.
      expect(strict.analysis.finalType, isNot(ThreatType.scam));
      expect(strict.analysis.ruleAnalysis.level, ThreatLevel.suspicious);
    });

    test('is never less sensitive than balanced', () {
      for (final text in <String>[
        weakSignal,
        'We detected unusual activity. Please confirm your account details '
            'using the link below within 24 hours.',
        'URGENT: your account is suspended. Verify your password immediately '
            'at http://hnb-secure-login.top to restore access.',
      ]) {
        final strict = _engine().analyzeText(text, mode: ProtectionMode.strict);
        final balanced = _engine().analyzeText(
          text,
          mode: ProtectionMode.balanced,
        );

        expect(
          _levelRank(strict.analysis.finalLevel),
          greaterThanOrEqualTo(_levelRank(balanced.analysis.finalLevel)),
          reason: text,
        );
        expect(
          strict.analysis.ruleAnalysis.riskScore,
          greaterThanOrEqualTo(balanced.analysis.ruleAnalysis.riskScore),
          reason: text,
        );
      }
    });

    test('mlDowngradeThreshold is live: strict needs more model certainty to '
        'clear a rule hit', () {
      // The model says legitimate; the rules say spam at 22/100. Clearing that
      // is exactly the branch `mlDowngradeThreshold` governs.
      String source(ProtectionMode mode, double confidence) =>
          HybridThreatAnalyzer(
            classifier: _FixedClassifier(MlThreatType.legitimate, confidence),
          ).analyze(spamSignal, mode: mode).source.name;

      // Balanced's threshold is 0.90, so a 0.92 model clears the rule hit …
      expect(source(ProtectionMode.balanced, 0.92), 'modelOverride');

      // … but Strict's is 0.95, so the same model call may not.
      expect(
        source(ProtectionMode.strict, 0.92),
        'ruleEngine',
        reason: 'strict downgrade threshold is 0.95, so 0.92 is not enough',
      );

      // Strict accepts the same model call once it clears its own threshold.
      expect(source(ProtectionMode.strict, 0.97), 'modelOverride');
    });

    test(
      'a model that cannot separate its classes does not clear a rule hit',
      () {
        // Balanced would accept 0.95 from a decisive model; this one's margin
        // between its top two classes is tiny, so it may not arbitrate.
        const blended = MlPrediction(
          type: MlThreatType.legitimate,
          confidence: 0.95,
          probabilities: [0.50, 0.48, 0.01, 0.005, 0.005],
        );
        expect(
          blended.margin,
          lessThan(HybridThreatAnalyzer.minDecisiveMargin),
        );

        final verdict = const HybridThreatAnalyzer(
          classifier: _AmbiguousClassifier(),
        ).analyze(spamSignal);

        // The weak rule hit wins when the model is not decisive.
        expect(verdict.finalType, isNot(ThreatType.legitimate));
        expect(verdict.source, VerdictSource.ruleEngine);
        expect(verdict.rationale, contains('too close to call'));
      },
    );
  });

  group('switching modes between analyses', () {
    test('a mode change clears the cache and changes the next verdict', () {
      final engine = _engine();

      expect(
        engine.analyzeText(weakSignal).analysis.finalLevel,
        ThreatLevel.safe,
      );

      engine.setMode(ProtectionMode.strict);
      expect(engine.mode, ProtectionMode.strict);
      expect(
        engine.analyzeText(weakSignal).analysis.finalLevel,
        ThreatLevel.suspicious,
      );
      expect(engine.cacheSize, 1, reason: 'the balanced entry was dropped');

      engine.setMode(ProtectionMode.balanced);
      expect(
        engine.analyzeText(weakSignal).analysis.finalLevel,
        ThreatLevel.safe,
      );
    });

    test('switching through AppServices reaches the engine immediately', () {
      final services = AppServices.instance;
      final original = services.protectionMode.value;

      addTearDown(() => services.protectionMode.value = original);

      services.protectionMode.value = ProtectionMode.strict;
      expect(services.threatEngine.mode, ProtectionMode.strict);

      services.protectionMode.value = ProtectionMode.relaxed;
      expect(services.threatEngine.mode, ProtectionMode.relaxed);

      services.protectionMode.value = original;
      expect(services.threatEngine.mode, original);
    });

    test(
      'automatic analysis uses the live mode, not a caller-supplied one',
      () {
        final engine = _engine()
          ..setEnabledChannels({MessageSource.sms})
          ..setMode(ProtectionMode.strict);

        final report = engine.analyzeMessage(
          const ThreatMessage(
            id: 'mode-live',
            body: weakSignal,
            source: MessageSource.sms,
            sender: '77000',
          ),
        );

        expect(report.analysis.protectionMode, ProtectionMode.strict);
        expect(report.analysis.finalLevel, ThreatLevel.suspicious);
      },
    );
  });

  group('legitimate bank and delivery notifications', () {
    const bank =
        'HNB: LKR 12,500.00 was debited from your account ending 4421 today. '
        'If this was not you, call the number on the back of your card '
        'immediately. Never share your OTP or password with anyone.';
    const delivery =
        'Your parcel has been dispatched and is out for delivery today. '
        'Tracking number SL7741203. No payment is required.';

    test('the bank debit alert stays safe in both modes', () {
      for (final mode in [ProtectionMode.balanced, ProtectionMode.strict]) {
        final analysis = _engine().analyzeText(bank, mode: mode).analysis;

        expect(analysis.finalLevel, ThreatLevel.safe, reason: mode.name);
        expect(analysis.finalType, ThreatType.legitimate, reason: mode.name);
        expect(
          analysis.ruleAnalysis.scoredEvidence,
          isNotEmpty,
          reason:
              'evidence scores are preserved even when benign context '
              'downgrades the verdict in ${mode.name}',
        );
      }
    });

    test('the delivery update stays safe in both modes', () {
      for (final mode in [ProtectionMode.balanced, ProtectionMode.strict]) {
        final analysis = _engine().analyzeText(delivery, mode: mode).analysis;

        expect(analysis.finalLevel, ThreatLevel.safe, reason: mode.name);
        expect(
          analysis.ruleAnalysis.scoredEvidence,
          isNotEmpty,
          reason:
              'evidence scores are preserved even when benign context '
              'downgrades the verdict in ${mode.name}',
        );
      }
    });
  });

  group('existing known threats', () {
    const phishing =
        'URGENT: your account is suspended. Verify your password immediately '
        'at http://hnb-secure-login.top to restore access.';

    test('a known phishing message is high risk in every mode', () {
      for (final mode in ProtectionMode.values) {
        final analysis = _engine().analyzeText(phishing, mode: mode).analysis;

        expect(analysis.finalLevel, ThreatLevel.highRisk, reason: mode.name);
        expect(analysis.finalType, isNot(ThreatType.legitimate));
      }
    });

    test('the mode is recorded on the rule analysis too', () {
      final analysis = _engine()
          .analyzeText(phishing, mode: ProtectionMode.relaxed)
          .analysis;

      expect(analysis.protectionMode, ProtectionMode.relaxed);
      expect(analysis.ruleAnalysis.mode, ProtectionMode.relaxed);
    });
  });
}

int _levelRank(ThreatLevel level) => switch (level) {
  ThreatLevel.safe => 0,
  ThreatLevel.suspicious => 1,
  ThreatLevel.highRisk => 2,
};
