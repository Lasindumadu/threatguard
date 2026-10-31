import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/services/app_services.dart';
import 'core/services/local_store.dart';
import 'core/services/threat_engine.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/presentation/screens/home_shell.dart';
import 'features/shell/presentation/widgets/cyber_splash_gate.dart';
import 'features/sms/application/inbox_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ThreatGuardApp());
}

class ThreatGuardApp extends StatefulWidget {
  const ThreatGuardApp({super.key});

  @override
  State<ThreatGuardApp> createState() => _ThreatGuardAppState();
}

class _ThreatGuardAppState extends State<ThreatGuardApp> {
  ThemeMode _themeMode = ThemeMode.system;

  LocalStore? _store;
  late final InboxController _controller;
  late final AppServices _services;

  @override
  void initState() {
    super.initState();

    // Both singletons are built once per process: the classifier trains once,
    // and every engine is composed once.
    _services = AppServices.instance;
    _controller = InboxController(engine: ThreatEngine.instance);

    _loadStore();
  }

  Future<void> _loadStore() async {
    try {
      final store = await LocalStore.load();
      await _controller.attachStore(store);

      // Restore every persisted setting into the live services. One call, so
      // the notifiers and the engine cannot disagree about what the user chose.
      //
      // Phase 1: online lookup and clipboard watch used to be left out of this
      // hydration, so they only took effect after the user re-toggled them in
      // the current session.
      final settings = store.settingsSnapshot;
      _services.applyPersistedSettings(
        mode: store.protectionMode,
        linkInterception: store.linkInterceptionEnabled,
        channels: store.enabledChannels,
        // A value the user never set stays at its default rather than being
        // forced to `false` by an absent key.
        onlineLookup: settings.onlineLookup ?? false,
        clipboardWatch: settings.clipboardWatch ?? false,
      );

      if (!mounted) return;
      setState(() {
        _store = store;
        _themeMode = _themeModeFrom(store.themeModeName);
      });
    } catch (_) {
      // Persistence is a convenience, never a hard dependency. If the platform
      // channel is unavailable the app still runs, just without saved state.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ThreatGuard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: CyberSplashGate(
        child: HomeShell(
          controller: _controller,
          store: _store,
          engine: ThreatEngine.instance,
          services: _services,
          themeMode: _themeMode,
          onThemeModeChanged: _onThemeModeChanged,
        ),
      ),
      builder: (context, child) {
        // Keep text scaling sane so large accessibility fonts do not break
        // the dense analysis cards.
        final scale = MediaQuery.textScalerOf(
          context,
        ).scale(1.0).clamp(1.0, 1.4);
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        );
      },
    );
  }

  void _onThemeModeChanged(ThemeMode mode) {
    setState(() => _themeMode = mode);
    _store?.setThemeMode(mode);
  }

  /// The stored theme choice was never read back, so a user's dark-mode choice
  /// silently reverted to "system" on every cold start.
  static ThemeMode _themeModeFrom(String? raw) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => ThemeMode.system,
    );
  }
}
