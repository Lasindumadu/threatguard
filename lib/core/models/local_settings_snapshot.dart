import 'message_source.dart';
import 'protection_mode.dart';

/// The persisted view of every user setting, as read from disk.
///
/// Phase 1 finding: the clipboard-watch toggle was applied **twice** — once in
/// `HomeShell` and once more inside `SettingsScreen` — and only one of them was
/// a live service. Any setting that drives a background behaviour needs one
/// place that says what it is, and one place that applies it.
///
/// The raw values are kept as strings/sets so a stored file written by an older
/// build still loads: unknown names degrade to the default instead of throwing
/// or silently dropping unrelated settings.
class LocalSettingsSnapshot {
  final String? protectionMode;
  final List<String>? enabledChannels;
  final String? themeMode;

  /// `null` means "not stored" — the caller decides the default. This is
  /// deliberately not `false`, because "the user has never chosen" and "the
  /// user chose off" are different facts.
  final bool? clipboardWatch;
  final bool? linkInterception;
  final bool? onlineLookup;

  const LocalSettingsSnapshot({
    this.protectionMode,
    this.enabledChannels,
    this.themeMode,
    this.clipboardWatch,
    this.linkInterception,
    this.onlineLookup,
  });

  ProtectionMode get mode => ProtectionMode.values.firstWhere(
    (value) => value.name == protectionMode,
    orElse: () => ProtectionMode.balanced,
  );

  /// Distinct, known channels. Unknown names (a channel removed in a later
  /// version) are ignored rather than crashing the load.
  Set<MessageSource>? get channels {
    final raw = enabledChannels;
    if (raw == null) return null;

    return {
      for (final name in raw)
        for (final source in MessageSource.values)
          if (source.name == name) source,
    };
  }

  Map<String, dynamic> toJson() => {
    'protectionMode': protectionMode,
    'enabledChannels': enabledChannels,
    'themeMode': themeMode,
    'clipboardWatch': clipboardWatch,
    'linkInterception': linkInterception,
    'onlineLookup': onlineLookup,
  };

  /// Tolerant parse: a malformed or partially-written value must not take the
  /// settings screen down, and must not reset the settings it *can* read.
  static LocalSettingsSnapshot fromJson(Map<String, dynamic> json) {
    bool? asBool(Object? value) => value is bool ? value : null;

    return LocalSettingsSnapshot(
      protectionMode: json['protectionMode'] as String?,
      enabledChannels: (json['enabledChannels'] as List?)
          ?.whereType<String>()
          .toList(growable: false),
      themeMode: json['themeMode'] as String?,
      clipboardWatch: asBool(json['clipboardWatch']),
      linkInterception: asBool(json['linkInterception']),
      onlineLookup: asBool(json['onlineLookup']),
    );
  }
}
