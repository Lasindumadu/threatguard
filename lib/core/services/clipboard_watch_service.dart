import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'link_safety_service.dart';
import 'url_extractor.dart';

/// A clipboard link that is worth offering to check.
class ClipboardSuggestion {
  final String url;
  final LinkSafety safety;

  const ClipboardSuggestion({required this.url, required this.safety});
}

/// Opt-in clipboard watcher.
///
/// Design constraints, all deliberate:
///
///  * **Off by default.** Reading someone's clipboard is invasive, so it never
///    happens unless the user turns it on, and the choice is stored.
///  * **Only URLs are surfaced.** The clipboard often holds passwords, private
///    messages and banking details. This service never displays, logs or stores
///    clipboard text — it extracts URLs, and only raises a suggestion for ones
///    that actually look risky. A safe link produces no UI at all.
///  * **Foreground only.** Android 10+ blocks background clipboard access for
///    non-focused apps precisely to stop silent snooping. The watcher is
///    lifecycle-aware: it stops when the app leaves the foreground and resumes
///    when it returns, rather than relying on the clipboard call to fail.
///  * **Rate-limited and single-flight.** A fixed interval, and never more than
///    one poll in flight, so a slow clipboard read can never queue up.
///  * **Latest wins.** If several links are copied between polls, the most
///    recent one is the one the user is about to tap. The previous
///    implementation evaluated the *first* URL found in the copied text rather
///    than the newest link.
///  * **Each distinct clipboard value once.** A handled link is not raised
///    again until the clipboard changes; warnings reappearing every three
///    seconds is how users learn to dismiss warnings.
class ClipboardWatchService with WidgetsBindingObserver {
  ClipboardWatchService({
    required this._safetyService,
    this.interval = const Duration(seconds: 3),
    this.minimumScore = 20,
    this.readClipboard,
    this.observeLifecycle = true,
    this.consentEnabled,
    this.channelEnabled,
  });

  final LinkSafetyService _safetyService;

  /// How often the clipboard is inspected while the app is in the foreground.
  final Duration interval;

  /// Minimum risk score before a suggestion is raised.
  ///
  /// Set at "suspicious", not zero: warning about every ordinary link would be
  /// noise, and noise is what teaches people to dismiss warnings.
  final int minimumScore;

  /// Test seam for the platform clipboard.
  final Future<String?> Function()? readClipboard;

  /// User consent for clipboard watching (the Settings switch).
  ///
  /// Read on every poll as well as on start, so consent revoked in Settings
  /// stops the watcher even if a caller forgot to call [stop]. `null` means
  /// "no external gate" (used by unit tests that drive polling directly).
  final bool Function()? consentEnabled;

  /// Whether the Clipboard *channel* is enabled in Shield.
  ///
  /// Phase 1 finding: the channel toggle listed Clipboard as a monitored
  /// channel, but the watcher never consulted it, so turning Clipboard off did
  /// not stop clipboard scanning.
  final bool Function()? channelEnabled;

  /// True only when consent, the Clipboard channel and the running timer all
  /// say yes.
  bool get isActive =>
      isRunning && (consentEnabled?.call() ?? true) && (channelEnabled?.call() ?? true);

  /// Whether to install a [WidgetsBindingObserver]. Unit tests that never
  /// initialise a binding set this to false.
  final bool observeLifecycle;

  Timer? _timer;
  bool _polling = false;
  bool _attached = false;
  bool _appVisible = true;

  /// The URL last acted on. Never raw clipboard text: only the link that was
  /// evaluated, so Settings can show what was inspected.
  String? _lastSeen;

  /// Links already evaluated as harmless. Bounded: only the most recent ones
  /// matter, and an unbounded set would grow for the life of the process.
  final Set<String> _suppressed = {};
  static const int _maxSuppressed = 64;

  Future<String?> _read() {
    final reader = readClipboard;
    return reader != null ? reader() : _readPlatformClipboard();
  }

  Future<String?> _readPlatformClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }

  final _controller = StreamController<ClipboardSuggestion>.broadcast();

  Stream<ClipboardSuggestion> get suggestions => _controller.stream;

  bool get isRunning => _timer != null;

  /// Surfaces for display in Settings so the user can see what it looked at.
  String? get lastCheckedUrl => _lastSeen;

  /// Whether the app is currently in the foreground.
  bool get isAppVisible => _appVisible;

  void start() {
    if (_timer != null) return;

    if (observeLifecycle && !_attached && WidgetsBinding.instance is WidgetsFlutterBinding) {
      WidgetsBinding.instance.addObserver(this);
      _attached = true;
    }

    _timer = Timer.periodic(interval, (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Full stop, including the lifecycle observer. Called on dispose.
  void detach() {
    stop();
    if (_attached) {
      WidgetsBinding.instance.removeObserver(this);
      _attached = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _appVisible = true;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // Stop inspecting the clipboard the moment this is no longer the
        // focused app. This is both the platform rule and the privacy promise.
        _appVisible = false;
    }
  }

  /// Runs exactly one poll. Test seam only.
  ///
  /// The production path is timer-driven; asserting "each link is raised once"
  /// needs the poll to be observable, not waited for on a three-second clock.
  @visibleForTesting
  Future<void> pollNowForTest() => _poll(force: true);

  Future<void> _poll({bool force = false}) async {
    // `force` is the test seam: it skips the timer and visibility gates but
    // never consent or the channel toggle, so those two are testable.
    if (!force && _timer == null) return;
    if (_polling) return;
    if (!_controller.hasListener) return;
    if (!force && !_appVisible) return;
    if (!(consentEnabled?.call() ?? true)) return;
    if (!(channelEnabled?.call() ?? true)) return;

    _polling = true;

    try {
      final text = await _read();
      if (text == null || text.trim().isEmpty) return;

      final clipped = text.length > 4000 ? text.substring(0, 4000) : text;

      // The last URL is the newest one the user copied.
      final urls = UrlExtractor.extract(clipped);
      if (urls.isEmpty) return;

      final candidate = urls.last;

      // Evaluate each distinct link once. Comparing the URL rather than the
      // whole text also means copying the same link again with extra text does
      // not re-alert.
      if (candidate == _lastSeen) return;
      if (_suppressed.contains(candidate)) return;

      final safety = _safetyService.analyzeOffline(candidate);

      // Recorded before the threshold check: a safe link is still "handled", so
      // it is not re-checked on every tick.
      _lastSeen = candidate;

      // A handled safe link still counts: a suppression list, so resetting the
      // memo to re-check one link cannot re-alert on the one next to it.
      if (safety.score < minimumScore) {
        if (_suppressed.length >= _maxSuppressed) {
          _suppressed.remove(_suppressed.first);
        }
        _suppressed.add(candidate);
        return;
      }

      if (!_controller.isClosed) {
        _controller.add(ClipboardSuggestion(url: candidate, safety: safety));
      }
    } catch (_) {
      // Clipboard access is refused in the background on Android 10+, and is
      // unavailable on web and in tests. None of that is an error worth
      // surfacing — the watcher simply has nothing to say.
    } finally {
      _polling = false;
    }
  }

  /// Clears the memo of the last-seen value.
  ///
  /// Only called when the user explicitly asks to check the clipboard again;
  /// never automatically, so a dismissed warning stays dismissed.
  void reset() {
    _lastSeen = null;
    _suppressed.clear();
  }

  Future<void> dispose() async {
    detach();
    await _controller.close();
  }
}
