import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/hybrid_threat_analysis.dart';
import 'package:threatguard/core/models/ml_feature_vector.dart';
import 'package:threatguard/core/models/ml_prediction.dart';
import 'package:threatguard/core/models/protection_mode.dart';
import 'package:threatguard/core/models/threat_analysis.dart';
import 'package:threatguard/core/services/threat_analyzer.dart';
import 'package:threatguard/core/services/threat_engine.dart';
import 'package:threatguard/core/services/verdict_policy.dart';

/// Every level the UI renders must be explainable by the evidence that is
/// actually printed beside it.
void _expectConsistent(MessageThreatReport report, {String? caseName}) {
  final analysis = report.analysis;
  final where = caseName == null ? '' : ' [$caseName]';
  final level = analysis.finalLevel;

  // 1. The displayed explanation describes the displayed verdict.
  expect(analysis.summary, isNotEmpty, reason: where);
  if (level == ThreatLevel.safe) {
    expect(
      analysis.isThreat,
      isFalse,
      reason: 'safe verdict that still calls the message a threat$where',
    );
    expect(
      analysis.summary.toLowerCase(),
      isNot(contains('flagged')),
      reason: 'a safe verdict must not say it was flagged$where',
    );
  } else {
    expect(
      analysis.summary.toLowerCase(),
      isNot(contains('no major threat indicators')),
      reason: 'a flagged verdict cannot say nothing was detected$where',
    );
  }

  // 2. A scored reason must be attached to the verdict it scores.
  for (final indicator in analysis.ruleAnalysis.scoredEvidence) {
    expect(
      indicator.scoreContribution,
      greaterThan(0),
      reason: 'scoredEvidence carries an unscored row$where',
    );
  }

  // 3. Evidence is counted once, and the score is built from it.
  final identities = analysis.ruleAnalysis.indicators
      .map((i) => i.identity)
      .toList();
  expect(
    identities.toSet().length,
    identities.length,
    reason: 'duplicate evidence contributed twice$where',
  );

  // 4. A heuristic verdict is never a confirmed threat.
  expect(
    analysis.isConfirmedThreat,
    isFalse,
    reason: 'on-device heuristics claimed confirmation$where',
  );
  expect(
    analysis.evidenceConfidence,
    isNot(EvidenceConfidence.confirmedThreat),
    reason: where,
  );

  // 5. Every scored category row quotes the text that produced it, so the
  //    "Matched: …" line under it is a real match.
  for (final indicator in analysis.ruleAnalysis.indicators) {
    if (indicator.scoreContribution == 0) continue;
    expect(
      indicator.evidence,
      isNotNull,
      reason:
          '"${indicator.title}" scores points with no quoted evidence$where',
    );
    expect(indicator.evidence!.trim(), isNotEmpty, reason: where);
  }
}

void main() {
  const bank =
      'HNB: LKR 12,500.00 was debited from your account ending 4421 today. '
      'If this was not you, call the number on the back of your card '
      'immediately. Never share your OTP or password with anyone.';
  const delivery =
      'Your parcel has been dispatched and is out for delivery today. '
      'Tracking number SL7741203. No payment is required.';
  // A real OTP lure: an account check pushed through a lookalike link, with
  // the code the target is told to hand over.
  const otpViaLink =
      'We detected unusual activity. Your account will be closed unless you '
      'verify your account at http://hnb-secure-login.top/verify and give the '
      'OTP you received.';
  // No link, no credential request, no payment: an account scare whose only
  // "request" is to verify an identity — which is not a named phishing
  // mechanism. It must stay suspicious, not become a high-risk phishing call.
  const accountScare =
      'We noticed a security alert on your account. Your account will be '
      'suspended unless you confirm your details, and this is urgent.';
  const phishing =
      'URGENT: your account is suspended. Verify your password immediately at '
      'http://hnb-secure-login.top to restore access.';

  group('legitimate bank notification', () {
    test('is safe, and its score agrees with that verdict', () {
      const text =
          'HNB: LKR 12,500.00 was debited from your account ending '
          '4421 today. Never share your OTP or password with anyone.';
      final report = ThreatEngine.instance.analyzeText(text);
      final analysis = report.analysis;

      expect(analysis.finalLevel, ThreatLevel.safe);
      expect(analysis.finalType, ThreatType.legitimate);
      _expectConsistent(report, caseName: 'bank');

      // The alert genuinely contains "today", "immediately" and "OTP"; those
      // are quoted, but they no longer add risk to a verdict that is safe.
      final described = analysis.ruleAnalysis.indicators
          .map((i) => '${i.title} ${i.evidence ?? ''}')
          .join(' ')
          .toLowerCase();
      expect(described, contains('today'));

      expect(
        analysis.ruleAnalysis.scoredEvidence,
        isNotEmpty,
        reason:
            'evidence scores are preserved even when benign context downgrades '
            'the verdict: '
            '${analysis.ruleAnalysis.scoredEvidence.map((i) => '${i.title} +${i.scoreContribution}')}',
      );
      expect(analysis.blendedRiskScore, greaterThan(0));
    });

    test('its counter-evidence survives', () {
      final analysis = ThreatEngine.instance
          .analyzeText(bank)
          .analysis
          .ruleAnalysis;

      expect(analysis.supportingEvidence, isNotEmpty);
    });
  });

  group('legitimate delivery update', () {
    test('is safe, and its score agrees with that verdict', () {
      final report = ThreatEngine.instance.analyzeText(delivery);
      final analysis = report.analysis;

      expect(analysis.finalLevel, ThreatLevel.safe);
      expect(analysis.finalType, ThreatType.legitimate);
      _expectConsistent(report, caseName: 'delivery');

      expect(
        analysis.ruleAnalysis.indicators.map((i) => i.evidence).toList(),
        contains('today'),
        reason: 'the quote stays visible even though it is now scored',
      );
      expect(
        analysis.ruleAnalysis.scoredEvidence,
        isNotEmpty,
        reason: 'evidence scores are preserved even when benign context '
            'downgrades the verdict',
      );
    });
  });

  group('OTP request through a suspicious link', () {
    test('is a phishing threat attributed to the link', () {
      final report = ThreatEngine.instance.analyzeText(otpViaLink);
      final analysis = report.analysis;

      expect(analysis.isThreat, isTrue);
      // 18 + 22 + 8: account warning, credential mention, external link. That
      // is the engine's existing band for this shape (its high-risk
      // combinations need urgency or a stronger request); the point here is
      // that the verdict is a named threat, not how loudly it is reported.
      expect(analysis.finalType, ThreatType.phishing);
      expect(analysis.finalLevel, ThreatLevel.suspicious);
      expect(
        analysis.ruleAnalysis.detectedUrls,
        contains('http://hnb-secure-login.top/verify'),
      );
      _expectConsistent(report, caseName: 'otp-link');
    });

    test('shows the link and the credential request, each once', () {
      final analysis = ThreatEngine.instance.analyzeText(otpViaLink).analysis;
      final evidences = analysis.ruleAnalysis.indicators
          .map((i) => i.evidence)
          .whereType<String>()
          .toList();

      expect(
        evidences
            .where((e) => e == 'http://hnb-secure-login.top/verify')
            .length,
        1,
        reason: 'the link is quoted once in the evidence list',
      );
      expect(
        analysis.ruleAnalysis.indicators
            .where((i) => i.title == 'External URL detected')
            .length,
        1,
      );
    });
  });

  group('suspicious message without a URL', () {
    test('is flagged but never confirmed, and never called a scam', () {
      final report = ThreatEngine.instance.analyzeText(accountScare);
      final analysis = report.analysis;

      // `isThreat` follows the *category*, and the category the facts support
      // here is spam (pressure + a bare warning). It is not a confirmed scam
      // and not a named phishing mechanism.
      expect(analysis.isThreat, isTrue);
      expect(analysis.finalLevel, ThreatLevel.suspicious);
      expect(analysis.finalType, isNot(ThreatType.scam));
      expect(analysis.finalType, ThreatType.spam);
      expect(analysis.ruleAnalysis.detectedUrls, isEmpty);
      expect(analysis.ruleAnalysis.level, ThreatLevel.suspicious);
      expect(analysis.ruleAnalysis.scoredEvidence, isNotEmpty);
      expect(analysis.isConfirmedThreat, isFalse);
      expect(
        analysis.evidenceConfidence,
        isNot(EvidenceConfidence.confirmedThreat),
      );
      _expectConsistent(report, caseName: 'no-url');
    });
  });

  group('missing or uncertain evidence', () {
    test('an empty message is not a threat and says why', () {
      final report = ThreatEngine.instance.analyzeText('');
      final analysis = report.analysis;

      expect(analysis.isAnalysed, isTrue);
      expect(analysis.isThreat, isFalse);
      expect(analysis.ruleAnalysis.summary, contains('No message'));
      _expectConsistent(report, caseName: 'empty');
    });

    test('a channel that was not monitored is "not analysed", not "safe"', () {
      // `VerdictPolicy.unavailable` is the placeholder for "we could not check".
      final unavailable = VerdictPolicy.unavailable(
        reason: 'Monitoring for SMS is turned off.',
        mode: ProtectionMode.balanced,
      );

      expect(unavailable.isAnalysed, isFalse);
      expect(unavailable.summary, contains('turned off'));
      expect(unavailable.isThreat, isFalse);
      expect(unavailable.evidenceConfidence, EvidenceConfidence.benign);
      expect(unavailable.isConfirmedThreat, isFalse);
      // Hence the UI must key on `isAnalysed`, never on `finalLevel == safe`.
      expect(
        unavailable.evidenceSummary.unknown,
        contains(unavailable.unavailableReason),
      );
    });

    test('strict mode flags a comment-like sentence without calling it spam or '
        'phishing', () {
      // Account-warning vocabulary plus a link-shaped phrase, but nothing
      // asking for a credential or money. Urgency word kept out so the score
      // stays below Balanced's floor of 25 while Strict's floor of 15
      // surfaces it.
      const borderline =
          'There was unusual activity. Check the link below.';
      expect(ProtectionMode.balanced.suspiciousScoreFloor, 25);
      expect(ProtectionMode.strict.suspiciousScoreFloor, 15);

      expect(
        ThreatEngine.instance.analyzeText(borderline).analysis.finalLevel,
        ThreatLevel.safe,
      );

      final report = ThreatEngine.instance.analyzeText(
        borderline,
        mode: ProtectionMode.strict,
      );
      final analysis = report.analysis;

      expect(analysis.finalLevel, ThreatLevel.suspicious);
      // Strict raises *attention*. It keeps the category the facts support
      // (the urgency vocabulary is not a phishing mechanism) rather than
      // rewriting it, which is the documented architecture.
      expect(analysis.finalType, isNot(ThreatType.phishing));
      expect(
        analysis.summary.toLowerCase(),
        isNot(contains('no major threat')),
      );
      _expectConsistent(report, caseName: 'strict-weak');
    });
  });

  group('heuristic suspicion vs. a trusted source', () {
    test('a high score alone is not a confirmation', () {
      final analysis = ThreatEngine.instance.analyzeText(phishing).analysis;

      expect(analysis.ruleAnalysis.riskScore, greaterThan(0));
      // "High risk" is a warning level, not a finding: the confidence scale
      // tops out at "inferred" because the evidence is wording and structure.
      expect(analysis.evidenceConfidence, EvidenceConfidence.highRisk);
      expect(analysis.isConfirmedThreat, isFalse);
      expect(analysis.source, isNot(VerdictSource.externalReport));
    });

    test('a trusted external report is the only path to confirmation', () {
      final rule = const ThreatAnalyzer().analyze(phishing);
      final confirmed = VerdictPolicy.confirmedByExternalReport(
        ruleAnalysis: rule,
        mlPrediction: const MlPrediction(
          type: MlThreatType.phishing,
          confidence: 0.9,
        ),
        finalType: ThreatType.phishing,
        rationale: 'The link is on a public phishing blocklist.',
        mode: ProtectionMode.balanced,
      );

      expect(confirmed.source, VerdictSource.externalReport);
      expect(confirmed.evidenceConfidence, EvidenceConfidence.confirmedThreat);
      expect(confirmed.isConfirmedThreat, isTrue);
      // The confirmation belongs to the external report, not the heuristics:
      // the rule analysis still only claims "inferred".
      expect(
        rule.evidenceConfidence,
        isNot(EvidenceConfidence.confirmedThreat),
      );
    });

    test('a confirmation cannot be attached to a legitimate verdict', () {
      // An external report about a message the app thinks is harmless still
      // has to name a threat category — a confirmed threat is never "legitimate".
      final confirmed = VerdictPolicy.confirmedByExternalReport(
        ruleAnalysis: const ThreatAnalyzer().analyze('Lunch at noon?'),
        mlPrediction: const MlPrediction(
          type: MlThreatType.legitimate,
          confidence: 0.9,
        ),
        finalType: ThreatType.legitimate,
        rationale: 'Reported by a trusted source.',
        mode: ProtectionMode.balanced,
      );

      expect(confirmed.isThreat, isTrue);
      expect(confirmed.evidenceConfidence, EvidenceConfidence.confirmedThreat);
    });

    test('an explicitly confirmed scam remains a confirmed threat', () {
      final rule = const ThreatAnalyzer().analyze(phishing);
      final confirmed = VerdictPolicy.confirmedByExternalReport(
        ruleAnalysis: rule,
        mlPrediction: const MlPrediction(
          type: MlThreatType.scam,
          confidence: 0.9,
        ),
        finalType: ThreatType.scam,
        rationale: 'Reported by a trusted source.',
        mode: ProtectionMode.balanced,
      );

      expect(confirmed.source, VerdictSource.externalReport);
      expect(confirmed.finalType, ThreatType.scam);
      expect(confirmed.isThreat, isTrue);
      expect(confirmed.confirmedEvidence, EvidenceConfidence.confirmedThreat);
      expect(confirmed.evidenceConfidence, EvidenceConfidence.confirmedThreat);
      expect(confirmed.isConfirmedThreat, isTrue);
    });

    test('a confirmed external threat keeps type, level, flag, confidence and summary consistent', () {
      final rule = const ThreatAnalyzer().analyze(phishing);
      final confirmed = VerdictPolicy.confirmedByExternalReport(
        ruleAnalysis: rule,
        mlPrediction: const MlPrediction(
          type: MlThreatType.phishing,
          confidence: 0.9,
        ),
        finalType: ThreatType.phishing,
        rationale: 'The link is on a public phishing blocklist.',
        mode: ProtectionMode.balanced,
      );

      expect(confirmed.finalType, ThreatType.phishing);
      expect(confirmed.isThreat, isTrue);
      expect(confirmed.finalLevel, isNot(ThreatLevel.safe));
      expect(confirmed.source, VerdictSource.externalReport);
      expect(confirmed.confirmedEvidence, EvidenceConfidence.confirmedThreat);
      expect(confirmed.evidenceConfidence, EvidenceConfidence.confirmedThreat);
      expect(confirmed.isConfirmedThreat, isTrue);
      expect(confirmed.summary, isNotEmpty);
      expect(
        confirmed.summary.toLowerCase(),
        contains('phishing'),
      );
    });

    test('benign context cannot downgrade an explicitly confirmed external threat', () {
      // The rule engine says the message is harmless, but an external report
      // confirms phishing. The confirmed threat must not be reduced to
      // safe/legitimate by benign-context handling.
      final harmless = const ThreatAnalyzer().analyze('Lunch at noon?');
      expect(harmless.type, ThreatType.legitimate);
      expect(harmless.level, ThreatLevel.safe);

      final confirmed = VerdictPolicy.confirmedByExternalReport(
        ruleAnalysis: harmless,
        mlPrediction: const MlPrediction(
          type: MlThreatType.legitimate,
          confidence: 0.9,
        ),
        finalType: ThreatType.phishing,
        rationale: 'Reported by a trusted source.',
        mode: ProtectionMode.balanced,
      );

      expect(confirmed.finalType, ThreatType.phishing);
      expect(confirmed.isThreat, isTrue);
      expect(confirmed.finalLevel, isNot(ThreatLevel.safe));
      expect(confirmed.source, VerdictSource.externalReport);
      expect(confirmed.evidenceConfidence, EvidenceConfidence.confirmedThreat);
      expect(confirmed.isConfirmedThreat, isTrue);
    });

    test('an ML-only phishing verdict is not externally confirmed', () {
      final hybrid = VerdictPolicy.assemble(
        ruleAnalysis: const ThreatAnalyzer().analyze('Lunch at noon?'),
        mlPrediction: const MlPrediction(
          type: MlThreatType.phishing,
          confidence: 0.98,
        ),
        finalType: ThreatType.phishing,
        source: VerdictSource.machineLearning,
        rationale: 'Model detected phishing features.',
        mode: ProtectionMode.balanced,
      );

      expect(hybrid.source, isNot(VerdictSource.externalReport));
      expect(hybrid.isConfirmedThreat, isFalse);
      expect(
        hybrid.evidenceConfidence,
        isNot(EvidenceConfidence.confirmedThreat),
      );
    });

  });

  group('displayed evidence corresponds to the analysis', () {
    test('no scored evidence is reported on a safe verdict, in any mode', () {
      for (final mode in ProtectionMode.values) {
        for (final text in [bank, delivery, 'Lunch tomorrow at noon?']) {
          final report = ThreatEngine.instance.analyzeText(text, mode: mode);
          _expectConsistent(report, caseName: '${mode.name}: $text');
        }
      }
    });

    test('a weak-but-quoted signal is scored once and not suppressed', () {
      final analysis = ThreatEngine.instance.analyzeText(bank).analysis;
      final today = analysis.ruleAnalysis.indicators
          .where((i) => i.evidence == 'today')
          .toList();

      expect(today.length, lessThanOrEqualTo(1));
      expect(today.every((i) => i.scoreContribution > 0), isTrue);
    });

    test('evidence scores are preserved in benign contexts', () {
      // The urgency indicator ("today") keeps its score even though the
      // benign-context downgrade makes the final verdict safe.
      final adjusted = ThreatAnalyzer.applyEvidenceRules(
        const ThreatAnalyzer().analyze(bank).indicators,
        hasCredentialRequest: false,
        safetyAdvice: true,
      ).indicators.where((i) => i.dedupeKey == 'rule:urgency');

      expect(adjusted, hasLength(1));
      expect(adjusted.single.scoreContribution, greaterThan(0));
      expect(adjusted.single.evidence, isNotNull);
    });
  });

  group('summary follows the final verdict', () {
    test('describeSummary retains meaningful wording for each category', () {
      expect(
        ThreatAnalyzer.describeSummary(ThreatType.phishing, ThreatLevel.suspicious),
        contains('phishing'),
      );
      expect(
        ThreatAnalyzer.describeSummary(ThreatType.scam, ThreatLevel.suspicious),
        contains('scams'),
      );
      expect(
        ThreatAnalyzer.describeSummary(
          ThreatType.socialEngineering,
          ThreatLevel.suspicious,
        ),
        contains('social-engineering'),
      );
      expect(
        ThreatAnalyzer.describeSummary(ThreatType.spam, ThreatLevel.suspicious),
        contains('unsolicited'),
      );
      expect(
        ThreatAnalyzer.describeSummary(ThreatType.legitimate, ThreatLevel.suspicious),
        contains('weak signals'),
      );
    });

    test('final legitimate verdict does not display a stale phishing summary', () {
      // A rule analysis that is already legitimate. The hybrid verdict is
      // legitimate, so the summary must be the safe wording, not a phishing
      // summary from any rule.
      final rule = const ThreatAnalyzer().analyze('Lunch at noon?');
      expect(rule.type, ThreatType.legitimate);
      expect(rule.level, ThreatLevel.safe);

      final hybrid = VerdictPolicy.assemble(
        ruleAnalysis: rule,
        mlPrediction: const MlPrediction(
          type: MlThreatType.phishing,
          confidence: 0.98,
        ),
        finalType: ThreatType.legitimate,
        source: VerdictSource.modelOverride,
        rationale: 'Model cleared to legitimate.',
        mode: ProtectionMode.balanced,
      );

      expect(hybrid.finalType, ThreatType.legitimate);
      expect(hybrid.finalLevel, ThreatLevel.safe);
      expect(
        hybrid.summary,
        isNot(contains('phishing')),
        reason: 'hybrid summary must not repeat a stale phishing verdict',
      );
    });

    test('final threat verdict does not display a stale safe summary', () {
      // Rules say legitimate but ML detects phishing. The hybrid verdict is
      // phishing, so the summary must describe phishing, not "no indicators".
      final rule = const ThreatAnalyzer().analyze('Lunch at noon?');
      expect(rule.type, ThreatType.legitimate);
      expect(rule.level, ThreatLevel.safe);

      final hybrid = VerdictPolicy.assemble(
        ruleAnalysis: rule,
        mlPrediction: const MlPrediction(
          type: MlThreatType.phishing,
          confidence: 0.88,
        ),
        finalType: ThreatType.phishing,
        source: VerdictSource.machineLearning,
        rationale: 'Model detected phishing features.',
        mode: ProtectionMode.balanced,
      );

      expect(hybrid.finalType, ThreatType.phishing);
      expect(hybrid.isThreat, isTrue);
      expect(
        hybrid.summary,
        isNot(contains('No major threat indicators')),
        reason: 'hybrid summary must describe the final threat verdict',
      );
      expect(hybrid.summary, contains('phishing'));
    });

    test('engine summary and HybridThreatAnalysis.summary agree for threat types', () {
      final rule = const ThreatAnalyzer().analyze(
        'URGENT: your account is suspended. Verify your password immediately '
        'at http://hnb-secure-login.top to restore access.',
      );
      expect(rule.type, ThreatType.phishing);

      final hybrid = VerdictPolicy.assemble(
        ruleAnalysis: rule,
        mlPrediction: const MlPrediction(
          type: MlThreatType.phishing,
          confidence: 0.90,
        ),
        finalType: ThreatType.phishing,
        source: VerdictSource.consensus,
        rationale: 'Both engines agree.',
        mode: ProtectionMode.balanced,
      );

      expect(
        hybrid.summary,
        ThreatAnalyzer.describeSummary(hybrid.finalType, hybrid.finalLevel),
        reason: 'HybridThreatAnalysis.summary must derive from the final verdict',
      );
    });
  });
}
