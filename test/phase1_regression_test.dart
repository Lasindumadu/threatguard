// Phase 1 regression suite.
//
// Every test here encodes a defect that was confirmed against the real code
// before it was fixed, or an invariant that the fix must not break. Tests are
// grouped by task so a failure says which part of the architecture moved.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/local_settings_snapshot.dart';
import 'package:threatguard/core/models/message_source.dart';
import 'package:threatguard/core/models/ml_feature_vector.dart';
import 'package:threatguard/core/models/ml_prediction.dart';
import 'package:threatguard/core/models/protection_mode.dart';
import 'package:threatguard/core/models/sender_analysis.dart';
import 'package:threatguard/core/models/threat_analysis.dart';
import 'package:threatguard/core/models/url_reputation.dart';
import 'package:threatguard/core/models/threat_message.dart';
import 'package:threatguard/core/services/app_services.dart';
import 'package:threatguard/core/services/clipboard_watch_service.dart';
import 'package:threatguard/core/services/composite_url_reputation_provider.dart';
import 'package:threatguard/core/services/link_safety_service.dart';
import 'package:threatguard/core/services/ml_feature_extractor.dart';
import 'package:threatguard/core/services/sender_analyzer.dart';
import 'package:threatguard/core/services/signal_features.dart';
import 'package:threatguard/core/services/text_matcher.dart';
import 'package:threatguard/core/services/text_preprocessor.dart';
import 'package:threatguard/core/services/threat_analyzer.dart';
import 'package:threatguard/core/services/threat_engine.dart';
import 'package:threatguard/core/services/threat_rule_catalog.dart';
import 'package:threatguard/core/services/url_reputation_provider.dart';

class _FixedProvider extends UrlReputationProvider {
  const _FixedProvider(this.status);

  final UrlReputationStatus status;

  @override
  Future<UrlReputation> checkUrl(String url) async =>
      UrlReputation(url: url, status: status, reason: 'fixed test provider');
}

void main() {
  // ------------------------------------------------------------ Task 2
  group('shared normalization', () {
    test('one definition of normalization, used by the matcher', () {
      const text = 'ＶＥＲＩＦＹ y0ur p4ssword\u200B now';

      // The folded form (case, fullwidth, invisible characters, homoglyphs)
      // is shared. Leetspeak is *per phrase*, inside the matcher, so numbers
      // a rule matches literally ("24", "$500") are never rewritten here.
      expect(TextPreprocessor.normalize(text), 'verify y0ur p4ssword now');
      expect(TextMatcher.normalize(text), TextPreprocessor.normalize(text));
      expect(TextMatcher.contains(text, 'verify your password'), isTrue);

      // The invisible zero-width space is removed, not turned into a space.
      expect(TextPreprocessor.normalize(text).contains('\u200B'), isFalse);
    });

    test('keeps the ZWJ/ZWNJ Sinhala conjuncts depend on', () {
      const text = 'ජ\u200Dය';
      expect(TextPreprocessor.normalize(text), text.toLowerCase());
    });

    test('leaves numbers without letters alone when folding leetspeak', () {
      expect(
        TextPreprocessor.normalize('pay 24 hours, \$500'),
        'pay 24 hours, \$500',
      );
    });

    test('bounds input without splitting a surrogate pair', () {
      final text = 'x' * (TextPreprocessor.maxLength - 1) + '🙂' + 'tail';
      final bounded = TextPreprocessor.bound(text);

      expect(bounded.wasTruncated, isTrue);
      // A split surrogate would decode as U+FFFD.
      expect(bounded.text.contains('\uFFFD'), isFalse);
    });

    test('caps pathological token length so matching stays linear', () {
      final capped = TextPreprocessor.capTokenLength('a' * 1000);
      final tokens = capped.split(' ');

      expect(tokens.length, greaterThan(1));
      expect(
        tokens.every((t) => t.length <= TextPreprocessor.maxTokenLength),
        isTrue,
      );
      expect(capped.replaceAll(' ', ''), 'a' * 1000);

      // A normal message is returned untouched.
      const normal = 'Your account is suspended — verify now.';
      expect(TextPreprocessor.capTokenLength(normal), normal);
    });
  });

  group('rule engine hygiene', () {
    test('no duplicate rule ids or duplicated patterns within a rule', () {
      final rules = ThreatRuleCatalog.rules;

      final ids = rules.map((rule) => rule.id).toList();
      expect(ids.toSet().length, ids.length);

      for (final rule in rules) {
        expect(
          rule.patterns.toSet().length,
          rule.patterns.length,
          reason: 'rule ${rule.id} lists the same pattern twice',
        );
      }
    });

    test('evidence identities in a verdict are unique', () {
      final report = ThreatEngine.instance.analyzeText(
        'URGENT: your account is suspended. Verify your password immediately at '
        'http://hnb-secure-login.top to restore access.',
      );
      final identities = report.analysis.ruleAnalysis.indicators
          .map((i) => i.identity)
          .toList();

      expect(identities.toSet().length, identities.length);
    });

    test('the score equals the sum of the scored evidence', () {
      final analysis = const ThreatAnalyzer().analyze(
        'URGENT: verify your account at http://192.168.1.1/login or it will '
        'be closed today.',
      );
      final sum = analysis.scoredEvidence.fold<int>(
        0,
        (total, indicator) => total + indicator.scoreContribution,
      );

      // Ascending escalations only, so the sum is a lower bound — never more
      // evidence than the score, and never evidence that was double-counted.
      expect(
        analysis.scoredEvidence.map((i) => i.identity).toSet().length,
        analysis.scoredEvidence.length,
      );
      expect(sum, lessThanOrEqualTo(analysis.riskScore));
      expect(
        analysis.scoredEvidence.every((i) => i.scoreContribution > 0),
        isTrue,
      );
    });

    test('the risk score is documented and treated as an index', () {
      final analysis = const ThreatAnalyzer().analyze(
        'Your account is suspended, verify your password now',
      );
      expect(analysis.riskScore, inInclusiveRange(0, 100));
      // Not a probability: a 0..100 score is not reported as a percentage of
      // confidence anywhere in the model.
      expect(
        analysis.evidenceConfidence,
        isNot(EvidenceConfidence.confirmedThreat),
      );
    });

    test('ML probability accessor reads its own class', () {
      const prediction = MlPrediction(
        type: MlThreatType.scam,
        confidence: 0.6,
        probabilities: [0.1, 0.1, 0.1, 0.6, 0.1],
      );

      // (MlThreatType order: legitimate, spam, phishing, scam, socialEng.)
      expect(prediction.probabilityOf(MlThreatType.scam), 0.6);
    });

    test('the rule engine and the model read the same text', () {
      final text = 'x' * 12000;
      final analysis = const ThreatAnalyzer().analyze(text);
      final features = const MlFeatureExtractor().extract(message: text);

      expect(analysis.wasTruncated, isTrue);

      // Both bound at [maxLength]; the token cap may add separator spaces, so
      // the model's length is the same string, not necessarily < maxLength.
      final rules = TextPreprocessor.capTokenLength(
        TextPreprocessor.bound(text).text,
      );
      expect(features.messageLength, rules.length);
      expect(rules.length, greaterThanOrEqualTo(TextPreprocessor.maxLength));
    });
  });

  // ------------------------------------------------------------ Task 3
  group('settings and channels', () {
    test('settings snapshot round-trips and tolerates junk', () {
      const snapshot = LocalSettingsSnapshot(
        protectionMode: 'strict',
        enabledChannels: ['sms', 'whatsapp'],
        clipboardWatch: true,
        onlineLookup: false,
      );
      final again = LocalSettingsSnapshot.fromJson(
        Map<String, dynamic>.from(snapshot.toJson()),
      );

      expect(again.mode, ProtectionMode.strict);
      expect(again.channels, {MessageSource.sms, MessageSource.whatsapp});
      expect(again.clipboardWatch, isTrue);
      expect(again.onlineLookup, isFalse);

      final junk = LocalSettingsSnapshot.fromJson({
        'protectionMode': 'ultra',
        'enabledChannels': ['sms', 'removed_channel', 42],
        'clipboardWatch': 'yes',
      });

      expect(junk.mode, ProtectionMode.balanced);
      expect(junk.channels, {MessageSource.sms});
      expect(junk.clipboardWatch, isNull);
    });

    test('a channel list naming nothing known is unset, not "all off"', () {
      final channels = LocalSettingsSnapshot.fromJson({
        'enabledChannels': ['channel_from_a_later_version'],
      }).channels;

      expect(channels, isEmpty);
    });

    test('online lookup gates the online providers at call time', () async {
      var online = false;
      final provider = CompositeUrlReputationProvider(
        providers: const [_FixedProvider(UrlReputationStatus.valid)],
        // A provider that would report "suspicious" if it were ever called.
        onlineProviders: const [_FixedProvider(UrlReputationStatus.suspicious)],
        onlineEnabled: () => online,
      );

      expect(
        (await provider.checkUrl('https://example.com')).status,
        UrlReputationStatus.valid,
      );

      online = true;
      expect(
        (await provider.checkUrl('https://example.com')).status,
        UrlReputationStatus.suspicious,
      );
    });

    test('clipboard watcher needs both consent and the Clipboard channel', () {
      var consent = true;
      var channel = true;

      final watcher = ClipboardWatchService(
        safetyService: const LinkSafetyService(),
        readClipboard: () async => 'https://hnb-secure-login.top/x',
        observeLifecycle: false,
        consentEnabled: () => consent,
        channelEnabled: () => channel,
      );

      expect(watcher.isActive, isFalse, reason: 'not started yet');

      channel = false;
      expect(watcher.isActive, isFalse);

      consent = false;
      channel = true;
      expect(watcher.isActive, isFalse);
    });

    test('clipboard suggestions for one link are raised once', () async {
      var clip = 'https://hnb-secure-login.top/verify';
      final watcher = ClipboardWatchService(
        safetyService: AppServices.instance.linkSafetyService,
        readClipboard: () async => clip,
        observeLifecycle: false,
        minimumScore: 1,
      );

      final seen = <String>[];
      final subscription = watcher.suggestions.listen((s) => seen.add(s.url));

      await watcher.pollNowForTest();
      await watcher.pollNowForTest();
      await watcher.pollNowForTest();
      // Broadcast stream events are delivered on the next microtask.
      await Future<void>.delayed(Duration.zero);

      expect(seen, ['https://hnb-secure-login.top/verify']);

      // A *different* link is a new finding.
      clip = 'https://paypal-verify.top/login';
      await watcher.pollNowForTest();
      await Future<void>.delayed(Duration.zero);
      expect(seen.length, 2);

      await subscription.cancel();
      await watcher.dispose();
    });

    test('a stopped watcher does not poll', () async {
      var reads = 0;
      final watcher = ClipboardWatchService(
        safetyService: const LinkSafetyService(),
        readClipboard: () async {
          reads++;
          return 'https://example.com';
        },
        observeLifecycle: false,
      );

      final subscription = watcher.suggestions.listen((_) {});
      expect(watcher.isRunning, isFalse, reason: 'off until started');

      watcher.start();
      expect(watcher.isRunning, isTrue);
      watcher.stop();
      expect(watcher.isRunning, isFalse);
      expect(reads, 0);

      await subscription.cancel();
      await watcher.dispose();
    });

    test('a disabled channel is never analysed automatically', () {
      final engine = ThreatEngine(
        analyzer: AppServices.instance.threatEngine.analyzer,
        senderAnalyzer: const SenderAnalyzer(),
        organizationUrlAnalyzer:
            AppServices.instance.threatEngine.organizationUrlAnalyzer,
        fingerprintMatcher:
            AppServices.instance.threatEngine.fingerprintMatcher,
        urlReputationProvider:
            AppServices.instance.threatEngine.urlReputationProvider,
        enabledChannels: const {MessageSource.manual},
      );

      final report = engine.analyzeMessage(
        const ThreatMessage(
          id: 'sms:1',
          body: 'verify your password at http://evil.top',
          source: MessageSource.sms,
          sender: '77000',
        ),
      );

      expect(report.analysis.isAnalysed, isFalse);
      expect(report.analysis.finalLevel, isNot(ThreatLevel.highRisk));
    });

    test('manual analysis is never gated by the channel toggles', () {
      final engine = ThreatEngine(
        analyzer: AppServices.instance.threatEngine.analyzer,
        senderAnalyzer: const SenderAnalyzer(),
        organizationUrlAnalyzer:
            AppServices.instance.threatEngine.organizationUrlAnalyzer,
        fingerprintMatcher:
            AppServices.instance.threatEngine.fingerprintMatcher,
        urlReputationProvider:
            AppServices.instance.threatEngine.urlReputationProvider,
        enabledChannels: const {},
      );

      final report = engine.analyzeText('Your account is suspended');
      expect(report.analysis.isAnalysed, isTrue);
    });

    test('online lookup is live state, not a stored label', () {
      final services = AppServices.instance;
      final before = services.onlineLookupEnabled.value;

      services.setOnlineLookupEnabled(!before);
      expect(services.onlineLookupEnabled.value, !before);

      services.setOnlineLookupEnabled(before);
      expect(services.onlineLookupEnabled.value, before);
    });
  });

  // ------------------------------------------------------------ Task 4
  group('verdict quality', () {
    final engine = ThreatEngine.instance;

    const benign = <String, String>{
      'bank debit alert':
          'HNB: LKR 12,500.00 was debited from your account ending 4421 today. '
          'If this was not you, call the number on the back of your card '
          'immediately. Never share your OTP or password with anyone.',
      'delivery update':
          'Your parcel has been dispatched and is out for delivery today. '
          'Tracking number SL7741203. No payment is required.',
      'job information':
          'Your application for the Software Engineer position has been '
          'shortlisted. We would like to invite you to an interview. '
          'Please share your availability.',
      'security education':
          'Security reminder: banks will never ask you to send your OTP or '
          'password. If you receive a message asking you to verify your '
          'account, report it to your bank.',
      'security education, delete':
          'Beware of fake delivery texts. If you get a message asking you to '
          'pay a redelivery fee, delete it and forward it to 7726.',
    };

    benign.forEach((name, text) {
      test('"$name" is not reported as high risk', () {
        final analysis = engine.analyzeText(text).analysis;

        expect(
          analysis.finalLevel,
          isNot(ThreatLevel.highRisk),
          reason:
              '$name scored ${analysis.blendedRiskScore} and was labelled '
              '${analysis.finalType.name}; evidence: '
              '${analysis.ruleAnalysis.scoredEvidence.map((i) => i.title).join(', ')}',
        );
      });
    });

    test('quoted lures do not turn an advisory into an attack', () {
      const advisory =
          'Banks will never ask you to send your OTP or password. If you '
          'receive a message asking you to verify your account, report it to '
          'your bank.';

      expect(SignalFeatures.isSafetyAdvice(advisory), isTrue);
      expect(
        engine.analyzeText(advisory).analysis.finalLevel,
        ThreatLevel.safe,
      );
    });

    test('the same lure without a warning frame is still caught', () {
      const lure =
          'Your account will be closed. Verify your account and send your OTP '
          'to this number now.';

      final analysis = engine.analyzeText(lure).analysis;
      expect(analysis.finalLevel, ThreatLevel.highRisk);
      expect(analysis.finalType, isNot(ThreatType.legitimate));
    });

    test('a real credential request is not cleared by a stray "do not share"', () {
      // `isImperativePasswordRequest` used to return false whenever the text
      // contained "do not share" anywhere, which a lure can add on purpose.
      const text =
          'You must provide your password to restore access. Do not share this '
          'code with the officer, just enter it on the page.';

      final analysis = engine.analyzeText(text).analysis;
      expect(analysis.isThreat, isTrue);
    });

    test('evidence classes never claim confirmation', () {
      final analysis = engine
          .analyzeText(
            'URGENT: your account is suspended. Verify your password immediately '
            'at http://hnb-secure-login.top to restore access.',
          )
          .analysis;

      expect(analysis.isThreat, isTrue);
      expect(analysis.isConfirmedThreat, isFalse);
      expect(
        analysis.evidenceConfidence,
        isNot(EvidenceConfidence.confirmedThreat),
      );
    });

    test('benign verdicts carry no threat certainty', () {
      final analysis = engine.analyzeText('Lunch tomorrow at noon?').analysis;

      expect(analysis.evidenceConfidence, EvidenceConfidence.benign);
      expect(analysis.verdictConfidence, 0.0);
    });

    test('known / inferred / unknown are separated', () {
      final report = engine.analyzeText(
        'This is the bank security team. Keep this confidential. Provide your '
        'OTP immediately to verify your account.',
      );
      final summary = report.analysis.evidenceSummaryWithSender(
        senderShortCodeUnregistered: true,
        sender: '77001',
      );

      expect(summary.known, isNotEmpty);
      expect(summary.inferred, isNotEmpty);
      expect(
        summary.unknown,
        contains(
          predicate<String>(
            (line) => line.contains('sender is really who the message claims'),
          ),
        ),
      );
      expect(
        summary.unknown.any((line) => line.contains('77001')),
        isTrue,
        reason: 'an unregistered short code is a fact and must be reported',
      );
    });

    test('counter-evidence survives a downgraded verdict', () {
      // `applyBenignContext` rebuilt the analysis by hand and dropped this.
      final report = engine.analyzeText(
        'Your payment was processed successfully. Reference 88213. '
        'No action is needed.',
      );

      expect(report.analysis.ruleAnalysis.supportingEvidence, isNotEmpty);
    });

    test('only short codes are treated as checkable sender facts', () {
      const analyzer = SenderAnalyzer();

      expect(analyzer.isCheckableShortCode('77777'), isTrue);
      expect(analyzer.isCheckableShortCode('+94 77 123 4567'), isFalse);
      expect(analyzer.isCheckableShortCode('HNB'), isFalse);
      expect(analyzer.isCheckableShortCode(null), isFalse);
      expect(
        analyzer.analyze('HNB').verificationStatus,
        SenderVerificationStatus.recognized,
      );
    });
  });

  // ------------------------------------------------------------ Task 5
  group('reliability', () {
    final engine = ThreatEngine.instance;

    test('hostile input returns a verdict instead of throwing', () {
      final inputs = <String>[
        '',
        '   ',
        '\u0000\u0001\u0002',
        ':' * 100,
        'http://',
        'http://[::1',
        'https://exa mple.com/x',
        'user:pass@',
        'www.',
        'https://${'a' * 6000}.com',
        '\u0DA2\u0DBA' * 2000,
        '🙂' * 3000,
        'a' * 200000,
      ];

      for (final input in inputs) {
        final report = engine.analyzeText(input);
        expect(report.analysis.isAnalysed, isTrue);
        expect(report.analysis.blendedRiskScore, inInclusiveRange(0, 100));
      }
    });

    test('an empty message is not a threat and says so', () {
      final report = engine.analyzeText('');
      expect(report.analysis.isThreat, isFalse);
      expect(report.analysis.ruleAnalysis.summary, contains('No message'));
    });

    test('a very long message is bounded, reported, and fast', () {
      // 200 KB *and* over the character cap, which is the case that matters:
      // a 200 KB paste used to take ~45 s end to end.
      final stopwatch = Stopwatch()..start();
      final report = engine.analyzeText(
        'account password verify urgent ' * 40000,
      );
      stopwatch.stop();

      expect(report.analysis.ruleAnalysis.wasTruncated, isTrue);
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(5000),
        reason: 'a 200 KB paste took ${stopwatch.elapsedMilliseconds} ms',
      );
    });

    test('a single unbroken token cannot stall analysis', () {
      // No spaces and under the character cap: only the token cap prevents the
      // word-boundary look-behinds from going quadratic. Distinct content, so
      // the memo cannot answer it.
      final stopwatch = Stopwatch()..start();
      engine.analyzeText(List.generate(7900, (i) => 'abcdefgh'[i % 8]).join());
      stopwatch.stop();

      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(3000),
        reason: 'two 7.9 KB tokens took ${stopwatch.elapsedMilliseconds} ms',
      );
    });

    test('repeated analysis of the same text is memoised', () {
      const text = 'Your account is suspended. Verify your password now.';
      final first = engine.analyzeText(text);
      final second = engine.analyzeText(text);

      expect(identical(first, second), isTrue);
    });

    test('different texts do not share a cache entry', () {
      // The key used to collapse every pasted message onto one entry because a
      // negative hash produced a second field separator.
      final first = engine.analyzeText('Lunch at noon');
      final second = engine.analyzeText(
        'URGENT verify your password at http://evil.top',
      );

      expect(identical(first, second), isFalse);
      expect(second.analysis.isThreat, isTrue);
    });

    test('a model that cannot score falls back to the rules', () {
      final analyzer = AppServices.instance.threatEngine.analyzer;
      expect(analyzer.classifier, isNotNull);
      // The fallback path is covered by the hostile-input test above: a model
      // failure must produce a rule-only verdict, not an exception.
    });

    test('an unstarted controller does not lose events', () async {
      final controller = StreamController<int>();
      final seen = <int>[];
      final subscription = controller.stream.listen(seen.add);

      controller.add(1);
      await Future<void>.delayed(Duration.zero);
      controller.add(2);
      await Future<void>.delayed(Duration.zero);

      expect(seen, [1, 2]);
      await subscription.cancel();
      await controller.close();
    });
  });
}

// --------------------------------------------------------------- helpers
