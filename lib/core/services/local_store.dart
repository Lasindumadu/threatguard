import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/local_settings_snapshot.dart';
import '../models/message_source.dart';
import '../models/protection_mode.dart';
import '../models/threat_analysis.dart';

/// What the user told us about a verdict.
enum UserFeedback {
  /// The verdict was right.
  confirmed,

  /// The message was a threat the app missed.
  missed,

  /// The message was safe but the app flagged it.
  falseAlarm,
}

/// One recorded feedback event, kept so it can be exported as a training set.
class FeedbackEntry {
  final String messageId;
  final String messageBody;
  final String? sender;
  final ThreatType predictedType;
  final UserFeedback feedback;
  final DateTime recordedAt;

  const FeedbackEntry({
    required this.messageId,
    required this.messageBody,
    required this.sender,
    required this.predictedType,
    required this.feedback,
    required this.recordedAt,
  });

  Map<String, dynamic> toJson() => {
    'messageId': messageId,
    'messageBody': messageBody,
    'sender': sender,
    'predictedType': predictedType.name,
    'feedback': feedback.name,
    'recordedAt': recordedAt.toIso8601String(),
  };

  /// CSV row for the exportable training set.
  String toCsvRow() {
    String esc(String? value) =>
        '"${(value ?? '').replaceAll('"', '""').replaceAll('\n', ' ')}"';

    return [
      esc(messageId),
      esc(sender),
      esc(predictedType.name),
      esc(feedback.name),
      esc(recordedAt.toIso8601String()),
      esc(messageBody),
    ].join(',');
  }

  static const csvHeader =
      'messageId,sender,predictedType,feedback,recordedAt,messageBody';
}

/// All persisted user state.
///
/// Design notes:
///  * Everything is local. There is no analytics SDK, no network call, and no
///    account — which is exactly what we want to be able to claim.
///  * Feedback is stored as raw JSON so it can be re-imported as a labelled
///    training set. That is the loop that makes the model improve over time.
class LocalStore {
  LocalStore._(this._prefs);

  final SharedPreferences _prefs;

  static const _kFeedback = 'feedback_entries';
  static const _kMutedSenders = 'muted_senders';
  static const _kOnlineLookup = 'online_lookup_enabled';
  static const _kStrictMode = 'strict_mode_enabled';
  static const _kProtectionMode = 'protection_mode';
  static const _kLinkInterception = 'link_interception_enabled';
  static const _kClipboardWatch = 'clipboard_watch_enabled';
  static const _kEnabledChannels = 'enabled_channels';
  static const _kThemeMode = 'theme_mode';
  static const _kAppSkin = 'app_skin';
  static const _kOnboarded = 'onboarding_complete';
  static const _kReduceMotion = 'reduce_motion_enabled';

  static LocalStore? _instance;

  static LocalStore? get maybeInstance => _instance;

  static Future<LocalStore> load() async {
    if (_instance != null) return _instance!;
    final prefs = await SharedPreferences.getInstance();
    return _instance = LocalStore._(prefs);
  }

  /// Test/support seam for a pre-built instance.
  static void overrideInstance(LocalStore? store) {
    _instance = store;
  }

  // ------------------------------------------------------------- settings

  bool get onlineLookupEnabled => _prefs.getBool(_kOnlineLookup) ?? false;

  Future<void> setOnlineLookupEnabled(bool value) =>
      _prefs.setBool(_kOnlineLookup, value);

  /// Strict mode lowers the alert threshold: more detections, more noise.
  bool get strictModeEnabled => _prefs.getBool(_kStrictMode) ?? false;

  /// Every setting at once, for the startup hydration in `main.dart`.
  ///
  /// Reading them individually is how `onlineLookupEnabled` ended up applied
  /// to nothing: there was no single "load the settings" step to notice it
  /// was missing from.
  LocalSettingsSnapshot get settingsSnapshot => LocalSettingsSnapshot(
    protectionMode: _prefs.getString(_kProtectionMode),
    enabledChannels: _prefs.getStringList(_kEnabledChannels),
    themeMode: _prefs.getString(_kThemeMode),
    skinId: _prefs.getString(_kAppSkin),
    clipboardWatch: _prefs.getBool(_kClipboardWatch),
    linkInterception: _prefs.getBool(_kLinkInterception),
    onlineLookup: _prefs.getBool(_kOnlineLookup),
    reduceMotion: _prefs.getBool(_kReduceMotion),
  );

  Future<void> setStrictModeEnabled(bool value) =>
      _prefs.setBool(_kStrictMode, value);

  // ------------------------------------------------------ protection mode

  /// Persisted detection sensitivity. Defaults to balanced.
  ProtectionMode get protectionMode {
    final raw = _prefs.getString(_kProtectionMode);

    return ProtectionMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => ProtectionMode.balanced,
    );
  }

  Future<void> setProtectionMode(ProtectionMode mode) async {
    await _prefs.setString(_kProtectionMode, mode.name);
    // Keep the legacy flag in sync so older logic cannot disagree.
    await _prefs.setBool(_kStrictMode, mode == ProtectionMode.strict);
  }

  // --------------------------------------------------- link interception

  bool get linkInterceptionEnabled =>
      _prefs.getBool(_kLinkInterception) ?? true;

  Future<void> setLinkInterceptionEnabled(bool value) =>
      _prefs.setBool(_kLinkInterception, value);

  // --------------------------------------------------- clipboard watch

  bool get clipboardWatchEnabled =>
      _prefs.getBool(_kClipboardWatch) ?? false;

  Future<void> setClipboardWatchEnabled(bool value) =>
      _prefs.setBool(_kClipboardWatch, value);

  // --------------------------------------------------- channel toggles

  /// Channels that are enabled for analysis. Defaults to all.
  /// Channels enabled for *automatic* monitoring.
  ///
  /// Every stored name is preserved, so turning one channel off never silently
  /// re-enables a different channel on the next load. Unknown names are
  /// ignored (a channel could be removed in a later version).
  Set<MessageSource> get enabledChannels {
    final raw = _prefs.getStringList(_kEnabledChannels);
    if (raw == null || raw.isEmpty) {
      // Default: all channels enabled
      return MessageSource.values.toSet();
    }

    final known = <MessageSource>{};
    for (final name in raw) {
      for (final source in MessageSource.values) {
        if (source.name == name) known.add(source);
      }
    }

    // A stored list that names no channel this build knows about is treated as
    // "unset" rather than "all monitoring off", which would look like data
    // loss to the user.
    return known.isEmpty ? MessageSource.values.toSet() : known;
  }

  Future<void> setChannelEnabled(MessageSource source, bool enabled) async {
    final current = enabledChannels;
    if (enabled) {
      current.add(source);
    } else {
      current.remove(source);
    }
    await _prefs.setStringList(
        _kEnabledChannels, current.map((e) => e.name).toList());
  }

  Future<void> setEnabledChannels(Set<MessageSource> channels) async {
    await _prefs.setStringList(
        _kEnabledChannels, channels.map((e) => e.name).toList());
  }

  // ------------------------------------------------------------- theme

  String? get themeModeName => _prefs.getString(_kThemeMode);

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(_kThemeMode, mode.name);

  String get skinId => _prefs.getString(_kAppSkin) ?? 'cyan';

  Future<void> setSkinId(String id) => _prefs.setString(_kAppSkin, id);

  bool get onboardingComplete => _prefs.getBool(_kOnboarded) ?? false;

  /// Whether the user has reduced motion enabled for accessibility.
  bool get reduceMotionEnabled =>
      _prefs.getBool(_kReduceMotion) ?? false;

  Future<void> setReduceMotionEnabled(bool value) =>
      _prefs.setBool(_kReduceMotion, value);

  // ---------------------------------------------------------------- muted

  Set<String> get mutedSenders =>
      (_prefs.getStringList(_kMutedSenders) ?? const []).toSet();

  Future<void> muteSender(String sender) async {
    final current = mutedSenders..add(sender);
    await _prefs.setStringList(_kMutedSenders, current.toList());
  }

  Future<void> unmuteSender(String sender) async {
    final current = mutedSenders..remove(sender);
    await _prefs.setStringList(_kMutedSenders, current.toList());
  }

  // ------------------------------------------------------------- feedback

  List<FeedbackEntry> get feedbackEntries {
    final raw = _prefs.getStringList(_kFeedback) ?? const [];

    return raw
        .map((entry) {
          try {
            final json = jsonDecode(entry) as Map<String, dynamic>;
            return FeedbackEntry(
              messageId: json['messageId'] as String? ?? '',
              messageBody: json['messageBody'] as String? ?? '',
              sender: json['sender'] as String?,
              predictedType: _parseType(json['predictedType'] as String?),
              feedback: _parseFeedback(json['feedback'] as String?),
              recordedAt:
                  DateTime.tryParse(json['recordedAt'] as String? ?? '') ??
                  DateTime.now(),
            );
          } catch (_) {
            // A corrupt row must never take down the whole store.
            return null;
          }
        })
        .whereType<FeedbackEntry>()
        .toList();
  }

  Future<void> addFeedback(FeedbackEntry entry) async {
    final raw = _prefs.getStringList(_kFeedback) ?? const [];
    final next = [...raw, jsonEncode(entry.toJson())];

    // Keep the store bounded; the oldest signals are the least useful.
    final bounded = next.length > 500 ? next.sublist(next.length - 500) : next;

    await _prefs.setStringList(_kFeedback, bounded);
  }

  Future<void> clearFeedback() => _prefs.remove(_kFeedback);

  /// Exports feedback as CSV so a user can inspect, share, or retrain with it.
  String exportFeedbackCsv() {
    final buffer = StringBuffer(FeedbackEntry.csvHeader)..writeln();
    for (final entry in feedbackEntries) {
      buffer.writeln(entry.toCsvRow());
    }
    return buffer.toString();
  }

  /// Counts of each feedback kind, for the settings screen.
  Map<UserFeedback, int> get feedbackSummary {
    final summary = <UserFeedback, int>{
      for (final value in UserFeedback.values) value: 0,
    };
    for (final entry in feedbackEntries) {
      summary[entry.feedback] = (summary[entry.feedback] ?? 0) + 1;
    }
    return summary;
  }

  // -------------------------------------------------------------- parsing

  static ThreatType _parseType(String? value) {
    return ThreatType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => ThreatType.legitimate,
    );
  }

  static UserFeedback _parseFeedback(String? value) {
    return UserFeedback.values.firstWhere(
      (f) => f.name == value,
      orElse: () => UserFeedback.confirmed,
    );
  }
}
