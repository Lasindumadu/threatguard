import 'package:flutter/foundation.dart';

import '../models/channel_profile.dart';
import '../models/hybrid_threat_analysis.dart';
import '../models/message_source.dart';
import '../models/organization_url_check.dart';
import '../models/protection_mode.dart';
import '../models/sender_analysis.dart';
import '../models/threat_message.dart';
import '../models/url_reputation.dart';
import 'composite_url_reputation_provider.dart';
import 'hybrid_threat_analyzer.dart';
import 'logistic_regression_classifier.dart';
import 'local_url_reputation_provider.dart';
import 'ml_feature_encoder.dart';
import 'ml_training_dataset.dart';
import 'organization_url_analyzer.dart';
import 'sender_analyzer.dart';
import 'template_fingerprint.dart';
import 'text_preprocessor.dart';
import 'unavailable_online_url_reputation_provider.dart';
import 'verdict_policy.dart';

/// Everything ThreatGuard knows about a single message.
///
/// Produced once and cached, so scrolling the inbox never re-runs the rules,
/// the model, the URL analysis and the sender lookup for the same message.
class MessageThreatReport {
  final ThreatMessage message;
  final HybridThreatAnalysis analysis;
  final SenderAnalysis senderAnalysis;
  final OrganizationUrlCheck organizationUrlCheck;
  final TemplateMatch? templateMatch;

  /// True when the sender used a short code that is not in the organisation
  /// registry — the one sender fact this app can actually check.
  ///
  /// Defaults to false so an existing constructor call (and its tests) keeps
  /// its current meaning.
  final bool senderShortCodeUnregistered;

  const MessageThreatReport({
    required this.message,
    required this.analysis,
    required this.senderAnalysis,
    required this.organizationUrlCheck,
    this.templateMatch,
    this.senderShortCodeUnregistered = false,
  });

  int get riskScore => analysis.blendedRiskScore;

  bool get isHighRisk => analysis.finalLevel.name == 'highRisk';
}

/// The single entry point the UI talks to.
///
/// Two important properties:
///
///  1. **The classifier is trained once per process.** Training is a 1000-epoch
///     gradient descent over the whole dataset; doing that in a widget's
///     `initState` (as the original code did) blocks the first frame.
///  2. **Results are memoised per message body.** The inbox used to re-analyse
///     every visible row on every rebuild.
class ThreatEngine {
  ThreatEngine({
    required this.analyzer,
    required this.senderAnalyzer,
    required this.organizationUrlAnalyzer,
    required this.fingerprintMatcher,
    required this.urlReputationProvider,
    Set<MessageSource> enabledChannels = const {},
    ProtectionMode mode = ProtectionMode.balanced,
    ValueNotifier<Set<MessageSource>>? channelNotifier,
    ValueNotifier<ProtectionMode>? modeNotifier,
  }) : _enabledChannels = channelNotifier ?? ValueNotifier(enabledChannels),
       _mode = modeNotifier ?? ValueNotifier(mode);

  final HybridThreatAnalyzer analyzer;
  final SenderAnalyzer senderAnalyzer;
  final OrganizationUrlAnalyzer organizationUrlAnalyzer;
  final TemplateFingerprintMatcher fingerprintMatcher;
  final CompositeUrlReputationProvider urlReputationProvider;

  /// Channels that are enabled for analysis.
  ///
  /// There is exactly one owner of this value ([AppServices.enabledChannels],
  /// which is hydrated from and persisted to [LocalStore]); the engine keeps a
  /// read-only mirror so it can gate automatic monitoring without every caller
  /// having to remember to check.
  final ValueNotifier<Set<MessageSource>> _enabledChannels;

  /// The live protection mode, owned by [AppServices].
  ///
  /// Callers no longer pass a mode in by hand: before this, the Shield tab
  /// wrote the mode into a notifier that nothing read, so Relaxed and Strict
  /// produced identical verdicts on every path. Every entry point now reads
  /// this notifier, and changing it clears the cache.
  final ValueNotifier<ProtectionMode> _mode;

  Set<MessageSource> get enabledChannels => _enabledChannels.value;

  ProtectionMode get mode => _mode.value;

  void setEnabledChannels(Set<MessageSource> channels) {
    if (setEquals(_enabledChannels.value, channels)) return;
    _enabledChannels.value = Set.unmodifiable(channels);
    clearCache();
  }

  void setMode(ProtectionMode mode) {
    if (_mode.value == mode) return;
    _mode.value = mode;
    clearCache();
  }

  static ThreatEngine? _instance;

  /// Process-wide singleton. Training happens exactly once, lazily, on first
  /// access — not once per screen.
  static ThreatEngine get instance => _instance ??= ThreatEngine._build();

  /// Test seam: allows a caller to inject a pre-built engine (e.g. a model
  /// trained on a different split).
  static void overrideInstance(ThreatEngine? engine) {
    _instance = engine;
  }

  static ThreatEngine _build() {
    final trainingExamples = const MlTrainingDataset().build();
    final featureEncoder = const MlFeatureEncoder();

    final featureVectors = trainingExamples
        .map((example) => featureEncoder.encode(example.features))
        .toList();

    final classifier = LogisticRegressionClassifier.train(
      examples: trainingExamples,
      featureVectors: featureVectors,
    );

    // Default: all channels enabled
    final defaultChannels = MessageSource.values.toSet();

    return ThreatEngine(
      analyzer: HybridThreatAnalyzer(classifier: classifier),
      senderAnalyzer: const SenderAnalyzer(),
      organizationUrlAnalyzer: const OrganizationUrlAnalyzer(),
      fingerprintMatcher: const TemplateFingerprintMatcher(),
      urlReputationProvider: const CompositeUrlReputationProvider(
        providers: [
          LocalUrlReputationProvider(),
          UnavailableOnlineUrlReputationProvider(),
        ],
      ),
      enabledChannels: defaultChannels,
    );
  }

  final Map<String, MessageThreatReport> _cache = {};

  /// Analyses a message from an *automatic* monitor (the SMS inbox scan).
  ///
  /// A disabled channel is genuinely skipped here: the user asked not to have
  /// that inbox read. The result is explicitly marked "not analysed", never
  /// "safe", so the UI cannot show a green tick for a message it never read.
  MessageThreatReport analyzeMessage(
    ThreatMessage message, {
    ProtectionMode? mode,
  }) {
    if (!_enabledChannels.value.contains(message.source)) {
      return _notAnalysed(
        message,
        'Monitoring for ${ChannelProfile.of(message.source).displayName} is '
        'turned off, so this message was not analysed.',
      );
    }

    return _report(message, mode ?? _mode.value);
  }

  /// Analyses content the user handed to the app deliberately: pasted text, a
  /// share from another app, or a link.
  ///
  /// Channel toggles do not gate this. The toggles control *automatic*
  /// monitoring; a user who pastes a message must still get an answer, and
  /// silently returning "channel disabled" would break the app's core manual
  /// feature. The channel still contributes its risk weighting, because
  /// provenance is evidence.
  MessageThreatReport analyzeText(
    String text, {
    MessageSource source = MessageSource.manual,
    ProtectionMode? mode,
    String? sender,
  }) {
    final effectiveMode = mode ?? _mode.value;

    // The id hashes the text as bounded for analysis, so two different long
    // pastes cannot share a cache entry. The body itself is passed through
    // whole: truncation belongs to the analyzer, which reports it.
    // Pre-truncating here made `ThreatAnalysis.wasTruncated` permanently false
    // for every pasted message, so the UI never told the user that the end of
    // a long message had not been read.
    final bounded = TextPreprocessor.bound(text).text;

    final message = ThreatMessage(
      // A cheap content-derived id keeps the memoisation correct for repeated
      // pastes of the same text without needing a counter or a random source.
      id: 'text:${_fingerprint(bounded)}:${source.name}',
      body: text,
      sender: sender,
      source: source,
    );

    return _report(message, effectiveMode);
  }

  static int _fingerprint(String text) {
    var hash = 0x811c9dc5;
    for (final unit in text.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
  MessageThreatReport _report(ThreatMessage message, ProtectionMode mode) {
    // Field-tagged and unit-separated: the id is content-derived, so a
    // separator character could otherwise occur inside it and let two
    // different messages resolve to one key.
    final cacheKey =
        '${message.source.name}\u0001${mode.name}\u0001${message.id}';

    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final report = _analyze(message, mode);

    // Bounded LRU-ish cache: a long-lived process that scans a large inbox and
    // then re-scans it must not hold every report for ever.
    if (_cache.length >= _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }

    _cache[cacheKey] = report;
    return report;
  }

  static const int _maxCacheEntries = 500;

  /// A report for a message that was deliberately not analysed.
  MessageThreatReport _notAnalysed(ThreatMessage message, String reason) {
    return MessageThreatReport(
      message: message,
      analysis: VerdictPolicy.unavailable(
        reason: reason,
        mode: _mode.value,
        channel: ChannelProfile.of(message.source),
      ),
      senderAnalysis: SenderAnalysis.unavailable,
      organizationUrlCheck: const OrganizationUrlCheck(
        consistency: OrganizationUrlConsistency.noUrl,
        organization: null,
        url: null,
        matchedDomain: null,
      ),
    );
  }

  /// Analyses several messages and registers them for template matching.
  List<MessageThreatReport> analyzeAll(
    List<ThreatMessage> messages, {
    ProtectionMode? mode,
  }) {
    final reports = [
      for (final message in messages) analyzeMessage(message, mode: mode),
    ];
    fingerprintMatcher.registerAll(reports);
    return reports;
  }

  MessageThreatReport _analyze(ThreatMessage message, ProtectionMode mode) {
    final HybridThreatAnalysis analysis;

    try {
      analysis = analyzer.analyze(
        message.body,
        mode: mode,
        source: message.source,
      );
    } catch (error) {
      // An engine failure must not take the screen down, and must not be
      // dressed up as "safe". The user gets an explicit "could not check".
      return _notAnalysed(
        message,
        'This message could not be analysed (${error.runtimeType}). '
        'Treat it with caution and verify the sender independently.',
      );
    }

    final senderAnalysis = senderAnalyzer.analyze(message.sender);

    final organizationUrlCheck = organizationUrlAnalyzer.analyze(
      senderAnalysis: senderAnalysis,
      urls: analysis.ruleAnalysis.detectedUrls,
    );

    final templateMatch = fingerprintMatcher.match(message.body);

    return MessageThreatReport(
      message: message,
      analysis: analysis,
      senderAnalysis: senderAnalysis,
      organizationUrlCheck: organizationUrlCheck,
      templateMatch: templateMatch,
      senderShortCodeUnregistered: senderAnalyzer.isCheckableShortCode(
        message.sender,
      ),
    );
  }

  /// On-device URL reputation lookup (offline heuristics + optional online).
  Future<UrlReputation> checkUrlReputation(String url) {
    return urlReputationProvider.checkUrl(url);
  }

  void clearCache() => _cache.clear();

  int get cacheSize => _cache.length;

  void dispose() {
    _enabledChannels.dispose();
    _mode.dispose();
  }
}
