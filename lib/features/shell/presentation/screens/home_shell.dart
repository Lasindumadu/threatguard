import 'package:flutter/material.dart';

import 'dart:async';

import '../../../../core/models/message_source.dart';
import '../../../../core/models/protection_mode.dart';
import '../../../../core/models/security_posture.dart';
import '../../../../core/services/app_services.dart';
import '../../../../core/services/clipboard_watch_service.dart';
import '../../../../core/services/local_store.dart';
import '../../../../core/services/shared_intake_service.dart';
import '../../../../core/services/threat_engine.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cyber_backdrop.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import '../../../insights/presentation/screens/model_insights_screen.dart';
import '../../../intake/presentation/screens/quick_verdict_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../shield/presentation/screens/shield_screen.dart';
import '../../../sms/application/inbox_controller.dart';
import '../../../sms/presentation/screens/sms_detail_screen.dart';
import '../../../sms/presentation/screens/sms_inbox_screen.dart';
import '../../../tools/presentation/screens/link_scanner_screen.dart';
import '../../../tools/presentation/screens/security_tips_screen.dart';
import '../../../tools/presentation/screens/tools_screen.dart';

/// Root navigation shell.
///
/// Five destinations, each answering a different question:
///  * **Dashboard** — am I okay?
///  * **Inbox** — what did we find?
///  * **Shield** — how is protection configured?
///  * **Tools** — check something specific.
///  * **Settings** — preferences and trust.
class HomeShell extends StatefulWidget {
  final InboxController controller;
  final LocalStore? store;
  final ThreatEngine engine;
  final AppServices services;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const HomeShell({
    super.key,
    required this.controller,
    required this.store,
    required this.engine,
    required this.services,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  late final SharedIntakeService _intakeService;
  late final ClipboardWatchService _clipboardWatchService;
  StreamSubscription<ClipboardSuggestion>? _clipboardSubscription;
  StreamSubscription<SharedIntake>? _intakeSubscription;

  /// Listens to the two settings that change what runs in the background, so
  /// the drawer controls re-render when they change anywhere (Shield, Settings,
  /// a restored store) instead of only after the widget that changed them
  /// rebuilds.
  final List<VoidCallback> _listenables = [];
  bool _initialised = false;

  @override
  void initState() {
    super.initState();

    _intakeService = SharedIntakeService();
    _intakeSubscription = _intakeService.intake.listen(_handleSharedIntake);
    _intakeService.start();

    _clipboardWatchService = ClipboardWatchService(
      safetyService: widget.services.linkSafetyService,
      // Both gates are read live from the single owners of those settings.
      consentEnabled: () => widget.services.clipboardWatchEnabled.value,
      channelEnabled: () => widget.services.enabledChannels.value.contains(
        MessageSource.clipboard,
      ),
    );

    // A clipboard finding is shown as a dismissible banner rather than pushed
    // as a route: the watcher polls, and pushing a route from a timer would
    // interrupt whatever the user is doing (or stack several banners).
    _clipboardSubscription = _clipboardWatchService.suggestions.listen(
      _showClipboardSuggestion,
    );

    for (final source in [
      widget.services.clipboardWatchEnabled,
      widget.services.enabledChannels,
      widget.services.protectionMode,
      widget.services.linkInterceptionEnabled,
    ]) {
      void listener() => setState(() {});
      source.addListener(listener);
      _listenables.add(() => source.removeListener(listener));
    }

    _syncClipboardWatcher();

    // The store arrives asynchronously; initialise the inbox once it is here so
    // a disabled SMS channel is honoured on the *first* scan, not after a tap.
    _initialiseInbox();

    // A share that launched the app arrives before Dart is listening, so the
    // pending payload is pulled explicitly rather than raced against.
    _intakeService.consumePending().then((intake) {
      if (intake != null && mounted) _handleSharedIntake(intake);
    });
  }

  Future<void> _initialiseInbox() async {
    while (!mounted) {
      return;
    }
    // Wait one microtask so `main.dart` can attach the store first; the
    // controller tolerates a null store either way.
    await Future<void>.delayed(Duration.zero);
    if (!mounted || _initialised) return;
    _initialised = true;
    await widget.controller.initialize();
  }

  @override
  void dispose() {
    for (final remove in _listenables) {
      remove();
    }
    _clipboardSubscription?.cancel();
    _intakeSubscription?.cancel();
    _intakeService.dispose();
    _clipboardWatchService.dispose();
    super.dispose();
  }

  /// Starts the watcher only when the user consented **and** the Clipboard
  /// channel is enabled; stops it otherwise.
  void _syncClipboardWatcher() {
    final shouldRun =
        widget.services.clipboardWatchEnabled.value &&
        widget.services.enabledChannels.value.contains(MessageSource.clipboard);

    if (shouldRun) {
      _clipboardWatchService.start();
    } else {
      _clipboardWatchService.stop();
    }
  }

  void _showClipboardSuggestion(ClipboardSuggestion suggestion) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    // Replaces any previous clipboard banner, so repeated findings cannot
    // pile up into a stack the user has to dismiss one by one.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(
            '${suggestion.safety.headline}: ${suggestion.safety.url}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          action: SnackBarAction(
            label: 'Check',
            onPressed: () {
              if (!mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LinkScannerScreen(
                    safetyService: widget.services.linkSafetyService,
                    initialUrl: suggestion.url,
                  ),
                ),
              );
            },
          ),
        ),
      );
  }

  /// Opens the quick verdict for text shared in from another app.
  void _handleSharedIntake(SharedIntake intake) {
    if (!mounted) return;

    // A disabled channel means "do not monitor this automatically". A share is
    // an explicit, per-message request, so it is always analysed; the banner
    // tells the user why instead of silently returning a canned "disabled".
    final enabled = widget.services.enabledChannels.value.contains(
      intake.source,
    );

    if (!enabled) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            '${intake.originLabel} is turned off in Shield, but you chose to '
            'share this message, so it was still checked.',
          ),
        ),
      );
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuickVerdictScreen(
          intake: intake,
          engine: widget.services.threatEngine,
          linkSafetyService: widget.services.linkSafetyService,
          onDismiss: () => Navigator.of(context).pop(),
          onCheckAnother: (next) {
            // Return to the analyst's paste screen so another message can be
            // checked without leaving the app.
            _checkAnother(next);
          },
        ),
      ),
    );
  }

  void _checkAnother(SharedIntake previous) {
    Navigator.of(context).pop();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Check another message'),
        content: const Text(
          'Open another app, select the message, and choose Share → '
          'ThreatGuard. It will be checked instantly.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  /// Applies a protection mode and persists it, so the setting survives a
  /// restart and the Shield tab stays the single source of truth.
  void _setProtectionMode(ProtectionMode mode) {
    setState(() => widget.services.protectionMode.value = mode);
    widget.store?.setProtectionMode(mode);
  }

  void _setLinkInterception(bool enabled) {
    setState(() => widget.services.linkInterceptionEnabled.value = enabled);
    widget.store?.setLinkInterceptionEnabled(enabled);
  }

  void _setEnabledChannels(Set<MessageSource> channels) {
    // This is an automatic-monitoring toggle. A disabled channel is skipped by
    // the inbox scan; it is never added to the manual analysis blocklist, so
    // pasted and shared content keeps working.
    setState(() => widget.services.enabledChannels.value = channels);
    widget.store?.setEnabledChannels(channels);

    // Clipboard is an automatic monitor too, so its toggle must actually stop
    // it rather than only relabelling a switch.
    _syncClipboardWatcher();

    if (!channels.contains(MessageSource.sms)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'SMS monitoring is off. You can still paste or share a message to '
            'check it.',
          ),
        ),
      );
    }
  }

  /// The single place clipboard consent is applied.
  ///
  /// `SettingsScreen` used to write the store and then call back here, which
  /// invoked this method twice. Ownership is now: Settings persists, this
  /// applies.
  void _setClipboardWatch(bool enabled) {
    widget.services.setClipboardWatchEnabled(enabled);
    _syncClipboardWatcher();
  }

  void _setOnlineLookup(bool enabled) {
    widget.services.setOnlineLookupEnabled(enabled);
  }

  /// Builds the device-posture assessment from what the app can actually know.
  SecurityPosture get _posture {
    final store = widget.store;

    return const SecurityPostureAssessor().assess(
      // A normal Android app cannot read the lock-screen setting, so this is
      // honestly reported as unknown rather than assumed enabled.
      screenLockEnabled: null,
      smsPermissionGranted: widget.controller.hasSmsPermission,
      onlineLookupEnabled:
          widget.services.onlineLookupEnabled.value ||
          (store?.onlineLookupEnabled ?? false),
      strictModeEnabled: widget.services.protectionMode.value.name == 'strict',
      mutedSenderCount: store?.mutedSenders.length ?? 0,
      feedbackGiven: store?.feedbackEntries.length ?? 0,
      scannedMessages: widget.controller.visibleMessages.length,
      highRiskMessages: 0,
    );
  }

  void _openTips() {
    final reports = widget.services.threatEngine.analyzeAll(
      widget.controller.visibleMessages,
    );

    final tips = widget.services.securityTipsEngine.generate(
      reports: reports,
      feedbackCount: widget.store?.feedbackEntries.length ?? 0,
      mutedSenderCount: widget.store?.mutedSenders.length ?? 0,
      hasSmsPermission: widget.controller.hasSmsPermission,
    );

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SecurityTipsScreen(tips: tips)));
  }

  @override
  Widget build(BuildContext context) {
    const titles = [
      'ThreatGuard',
      'Inbox',
      'Shield',
      'Security tools',
      'Settings',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.shield_rounded,
                size: 18,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(width: 10),
            Text(titles[_index]),
          ],
        ),
        actions: [
          if (_index == 1 && widget.controller.hasSmsPermission)
            IconButton(
              tooltip: 'Rescan messages',
              onPressed: widget.controller.isLoading
                  ? null
                  : widget.controller.loadMessages,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: CyberBackdrop(
        child: IndexedStack(
          index: _index,
          children: [
            ValueListenableBuilder(
              valueListenable: widget.services.protectionMode,
              builder: (context, _, child) => DashboardScreen(
                messages: widget.controller.visibleMessages,
                engine: widget.engine,
                posture: _posture,
                isScanning: widget.controller.isLoading,
                statusMessage: widget.controller.errorMessage,
                onScanRequested: widget.controller.hasSmsPermission
                    ? widget.controller.loadMessages
                    : widget.controller.requestPermission,
                onOpenTools: () => setState(() => _index = 3),
                onOpenMessage: _openMessage,
              ),
            ),
            SmsInboxScreen(controller: widget.controller),
            ShieldScreen(
              mode: widget.services.protectionMode.value,
              onModeChanged: (mode) => _setProtectionMode(mode),
              reports: widget.services.threatEngine.analyzeAll(
                widget.controller.visibleMessages,
              ),
              mutedSenders: widget.store?.mutedSenders ?? const {},
              onUnmute: (sender) => widget.controller.unmuteSender(sender),
              onOpenLinkScanner: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LinkScannerScreen(
                    safetyService: widget.services.linkSafetyService,
                  ),
                ),
              ),
              linkInterceptionEnabled:
                  widget.services.linkInterceptionEnabled.value,
              onLinkInterceptionChanged: (value) => _setLinkInterception(value),
              enabledChannels: widget.services.enabledChannels.value,
              onEnabledChannelsChanged: (channels) => _setEnabledChannels(channels),
              store: widget.store,
              calibrator: widget.services.feedbackCalibrator,
              alertService: widget.services.securityAlertService,
            ),
            ToolsScreen(
              linkSafetyService: widget.services.linkSafetyService,
              breachCheckService: widget.services.breachCheckService,
              onOpenTips: _openTips,
            ),
            SettingsScreen(
              store: widget.store,
              engine: widget.engine,
              themeMode: widget.themeMode,
              onThemeModeChanged: widget.onThemeModeChanged,
              onOpenInsights: _openInsights,
              onOpenShield: () => setState(() => _index = 2),
              onClipboardWatchChanged: _setClipboardWatch,
              onOnlineLookupChanged: _setOnlineLookup,
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'Inbox',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield),
            label: 'Shield',
          ),
          NavigationDestination(
            icon: Icon(Icons.widgets_outlined),
            selectedIcon: Icon(Icons.widgets),
            label: 'Tools',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  /// Opens a message's analysis, switching to the inbox tab so the user has
  /// context behind the pushed route.
  void _openMessage(MessageThreatReport report) {
    setState(() => _index = 1);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SmsDetailScreen(
          report: report,
          engine: widget.engine,
          controller: widget.controller,
        ),
      ),
    );
  }

  void _openInsights() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ModelInsightsScreen()));
  }
}
