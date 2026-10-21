import 'package:flutter/foundation.dart';

import '../models/message_source.dart';
import '../models/protection_mode.dart';
import 'breach_check_service.dart';
import 'composite_url_reputation_provider.dart';
import 'feedback_calibrator.dart';
import 'hybrid_threat_analyzer.dart';
import 'impersonation_detector.dart';
import 'link_safety_service.dart';
import 'logistic_regression_classifier.dart';
import 'local_url_reputation_provider.dart';
import 'ml_feature_encoder.dart';
import 'ml_training_dataset.dart';
import 'organization_registry.dart';
import 'organization_url_analyzer.dart';
import 'security_alert_service.dart';
import 'security_tips_engine.dart';
import 'sender_analyzer.dart';
import 'template_fingerprint.dart';
import 'threat_engine.dart';
import 'unavailable_online_url_reputation_provider.dart';
import 'url_forensics_analyzer.dart';

/// Single composition root for every engine.
///
/// Before this, screens each constructed their own analysers, which meant the
/// URL-forensics engine could drift from the one the message analyzer used, and
/// every new screen added another hidden dependency. Everything is built once
/// here and passed down.
class AppServices {
  final ThreatEngine threatEngine;
  final LinkSafetyService linkSafetyService;
  final BreachCheckService breachCheckService;
  final SecurityTipsEngine securityTipsEngine;
  final FeedbackCalibrator feedbackCalibrator;
  final SecurityAlertService securityAlertService;

  /// Runtime configuration, owned here so no screen has to reach into storage.
  ///
  /// These notifiers are the single source of truth for live settings. They are
  /// handed to [ThreatEngine] by reference, so "the model thinks Strict" and
  /// "the dashboard shows Strict" cannot diverge — there is one value.
  final ValueNotifier<ProtectionMode> protectionMode;
  final ValueNotifier<bool> linkInterceptionEnabled;
  final ValueNotifier<Set<MessageSource>> enabledChannels;

  /// Whether the user opted in to online link-reputation lookup.
  ///
  /// Phase 1 finding: this was persisted in `LocalStore` and read only by the
  /// Settings *subtitle* and the posture card. The reputation provider was
  /// hard-wired to "online unavailable", so the switch changed a label and
  /// nothing else. It is now live state, read at the moment a lookup is made.
  final ValueNotifier<bool> onlineLookupEnabled;

  /// Whether clipboard watching is on.
  ///
  /// Also live state: the Clipboard channel toggle and this switch both gate
  /// the same watcher, and they must read one value rather than two copies.
  final ValueNotifier<bool> clipboardWatchEnabled = ValueNotifier(false);

  AppServices._({
    required this.threatEngine,
    required this.linkSafetyService,
    required this.breachCheckService,
    required this.securityTipsEngine,
    required this.feedbackCalibrator,
    required this.securityAlertService,
    required this.protectionMode,
    required this.linkInterceptionEnabled,
    required this.enabledChannels,
    required this.onlineLookupEnabled,
  }) {
    // Changing a channel toggle takes effect immediately: the engine clears its
    // cache when the value actually changes.
    enabledChannels.addListener(_syncEnabledChannels);
    protectionMode.addListener(_syncProtectionMode);
    _syncEnabledChannels();
    _syncProtectionMode();
  }

  void _syncEnabledChannels() {
    threatEngine.setEnabledChannels(enabledChannels.value);
  }

  void _syncProtectionMode() {
    threatEngine.setMode(protectionMode.value);
  }

  /// Applies settings loaded from disk without a widget rebuild round-trip.
  ///
  /// Used by `main.dart` on startup. Each setter is a no-op when the value is
  /// unchanged, so re-hydrating never needlessly clears the analysis cache.
  void applyPersistedSettings({
    required ProtectionMode mode,
    required bool linkInterception,
    required Set<MessageSource> channels,
    bool? onlineLookup,
    bool? clipboardWatch,
  }) {
    protectionMode.value = mode;
    linkInterceptionEnabled.value = linkInterception;
    enabledChannels.value = Set.unmodifiable(channels);
    if (onlineLookup != null) onlineLookupEnabled.value = onlineLookup;
    if (clipboardWatch != null) clipboardWatchEnabled.value = clipboardWatch;
  }

  void setOnlineLookupEnabled(bool enabled) {
    onlineLookupEnabled.value = enabled;
  }

  void setClipboardWatchEnabled(bool enabled) {
    clipboardWatchEnabled.value = enabled;
  }

  static AppServices? _instance;

  static AppServices get instance => _instance ??= _build();

  static void overrideInstance(AppServices? services) => _instance = services;

  static AppServices _build() {
    // Every official domain from the organisation registry, flattened into the
    // brand list the impersonation detector compares against.
    //
    // This is load-bearing: the detector's default constructor has an EMPTY
    // domain list, so wiring it up without the registry silently disables
    // brand-impersonation detection entirely — the link scanner would report
    // "no problems found" for a bank lookalike.
    final officialDomains = <String>[
      for (final profile in const OrganizationRegistry().profiles)
        ...profile.officialDomains,
    ];

    final forensics = UrlForensicsAnalyzer(
      impersonationDetector: ImpersonationDetector(
        officialDomains: officialDomains,
      ),
    );

    // Default: all channels enabled.
    final defaultChannels = MessageSource.values.toSet();

    // The notifiers are created here and shared with the engine, rather than
    // the engine owning a mirror that has to be kept in sync by hand.
    final modeNotifier = ValueNotifier(ProtectionMode.balanced);
    final channelNotifier = ValueNotifier(Set.unmodifiable(defaultChannels));

    final trainingExamples = const MlTrainingDataset().build();
    final featureEncoder = const MlFeatureEncoder();

    final classifier = LogisticRegressionClassifier.train(
      examples: trainingExamples,
      featureVectors: trainingExamples
          .map((e) => featureEncoder.encode(e.features))
          .toList(),
    );

    final onlineNotifier = ValueNotifier(false);

    // The composite provider is constructed *without* an online provider and
    // given one at lookup time only when the user opted in, so "off" means the
    // network path is not merely skipped but absent.
    final reputationProvider = CompositeUrlReputationProvider(
      providers: const [LocalUrlReputationProvider()],
      onlineProviders: const [UnavailableOnlineUrlReputationProvider()],
      onlineEnabled: () => onlineNotifier.value,
    );

    final threatEngine = ThreatEngine(
      analyzer: HybridThreatAnalyzer(classifier: classifier),
      senderAnalyzer: const SenderAnalyzer(),
      organizationUrlAnalyzer: const OrganizationUrlAnalyzer(),
      fingerprintMatcher: const TemplateFingerprintMatcher(),
      urlReputationProvider: reputationProvider,
      channelNotifier: channelNotifier,
      modeNotifier: modeNotifier,
    );

    return AppServices._(
      threatEngine: threatEngine,
      linkSafetyService: LinkSafetyService(forensicsAnalyzer: forensics),
      breachCheckService: const BreachCheckService(),
      securityTipsEngine: const SecurityTipsEngine(),
      feedbackCalibrator: const FeedbackCalibrator(),
      securityAlertService: const SecurityAlertService(),
      protectionMode: modeNotifier,
      linkInterceptionEnabled: ValueNotifier(true),
      enabledChannels: channelNotifier,
      onlineLookupEnabled: onlineNotifier,
    );
  }

  void dispose() {
    enabledChannels.removeListener(_syncEnabledChannels);
    protectionMode.removeListener(_syncProtectionMode);
    protectionMode.dispose();
    linkInterceptionEnabled.dispose();
    enabledChannels.dispose();
    onlineLookupEnabled.dispose();
    clipboardWatchEnabled.dispose();
    threatEngine.dispose();
  }
}