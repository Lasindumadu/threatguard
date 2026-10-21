import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../../core/models/threat_analysis.dart';

/// ThreatGuard's design language.
///
/// This exists so the app does not read as "Material with a seed colour". A
/// default `ColorScheme.fromSeed` produces the same indigo-ish ramp in every
/// Flutter project; here every surface, border and accent is named and chosen
/// deliberately, and the risk palette is a hand-picked, hue-separated set that
/// stays distinguishable for colour-blind users.
class AppTheme {
  const AppTheme._();

  // ---------------------------------------------------------------- brand
  //
  // A deep teal-navy rather than the default indigo. It reads as "security
  // tooling" and leaves the warm spectrum free for risk signalling, so a red or
  // amber element is never confused with brand chrome.
  static const seed = Color(0xFF0E4C63);
  static const accent = Color(0xFF00B8D4);

  // ------------------------------------------------------------ risk ramp
  //
  // Four states, chosen to be separable by hue *and* lightness so the
  // distinction survives deuteranopia and greyscale.
  static const safeColor = Color(0xFF12996B);
  static const suspiciousColor = Color(0xFFE08A00);
  static const highRiskColor = Color(0xFFE0384C);
  static const criticalColor = Color(0xFF9B1B30);
  static const unknownColor = Color(0xFF64748B);

  /// Category accents, each a distinct hue so the five-way breakdown is
  /// readable at a glance.
  static const phishingColor = Color(0xFFE0384C);
  static const scamColor = Color(0xFF9B4DCA);
  static const socialColor = Color(0xFFE08A00);
  static const spamColor = Color(0xFF64748B);
  static const legitimateColor = Color(0xFF12996B);

  // ------------------------------------------------------------- geometry
  static const radiusSm = 10.0;
  static const radiusMd = 16.0;
  static const radiusLg = 22.0;
  static const radiusXl = 28.0;

  static const gapXs = 4.0;
  static const gapSm = 8.0;
  static const gapMd = 16.0;
  static const gapLg = 24.0;
  static const gapXl = 32.0;

  /// One tempo for the whole product: every transition moves at the same
  /// speed, which is what makes an app feel coherent rather than assembled.
  static const motionFast = Duration(milliseconds: 180);
  static const motionBase = Duration(milliseconds: 320);
  static const motionSlow = Duration(milliseconds: 620);
  static const motionCurve = Curves.easeOutCubic;

  // ------------------------------------------------------------- surfaces
  static const lightSurface = Color(0xFFF4F6F9);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE2E7EE);
  static const lightMuted = Color(0xFF5A6472);

  static const darkSurface = Color(0xFF0B1218);
  static const darkCard = Color(0xFF141D26);
  static const darkElevated = Color(0xFF1B2630);
  static const darkBorder = Color(0xFF25313D);
  static const darkMuted = Color(0xFF93A2B3);

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  /// True in dark mode, for the places that need a different gradient rather
  /// than just a different colour.
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static ThemeData _base(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    // Hand-built scheme rather than fromSeed: fromSeed would replace the brand
    // ramp with its own tonal palette and flatten primary against accent.
    final scheme = ColorScheme(
      brightness: brightness,
      primary: isLight ? seed : accent,
      onPrimary: isLight ? Colors.white : const Color(0xFF00212B),
      primaryContainer: isLight
          ? const Color(0xFFCDE7EF)
          : const Color(0xFF0F3948),
      onPrimaryContainer: isLight
          ? const Color(0xFF062430)
          : const Color(0xFFB8E4F0),
      secondary: accent,
      onSecondary: const Color(0xFF00212B),
      secondaryContainer: isLight
          ? const Color(0xFFC7F0F8)
          : const Color(0xFF0B3B48),
      onSecondaryContainer: isLight
          ? const Color(0xFF002F3B)
          : const Color(0xFFB0E7F2),
      tertiary: const Color(0xFF7C5CFF),
      onTertiary: Colors.white,
      error: highRiskColor,
      onError: Colors.white,
      surface: isLight ? lightSurface : darkSurface,
      onSurface: isLight ? const Color(0xFF121820) : const Color(0xFFE8EEF4),
      onSurfaceVariant: isLight ? lightMuted : darkMuted,
      outline: isLight ? lightBorder : darkBorder,
      outlineVariant: isLight
          ? const Color(0xFFEDF0F4)
          : const Color(0xFF1E2832),
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: isLight
          ? const Color(0xFF1B2630)
          : const Color(0xFFE8EEF4),
      onInverseSurface: isLight
          ? const Color(0xFFE8EEF4)
          : const Color(0xFF1B2630),
      inversePrimary: accent,
      surfaceContainerHighest: isLight ? const Color(0xFFE9EDF3) : darkElevated,
    );

    final border = isLight ? lightBorder : darkBorder;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isLight ? lightSurface : darkSurface,

      // Slightly tightened tracking on headings and a generous body line
      // height: the difference between "Flutter default" and designed.
      textTheme: _textTheme(scheme),

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isLight ? lightCard : darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(color: border),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : darkCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: scheme.primary, width: 1.8),
        ),
        labelStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: isLight ? lightCard : darkCard,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: isLight ? 0.13 : 0.22),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 23,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: isLight ? Colors.white : darkElevated,
        selectedColor: scheme.primary.withValues(alpha: 0.14),
        side: BorderSide(color: border),
        labelStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      dividerTheme: DividerThemeData(color: border, space: 1, thickness: 1),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight ? const Color(0xFF1B2630) : darkElevated,
        contentTextStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        insetPadding: const EdgeInsets.all(16),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: border,
        circularTrackColor: border,
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: border)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm),
            ),
          ),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : (isLight ? const Color(0xFFB6BEC9) : const Color(0xFF4A5765)),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : (isLight ? const Color(0xFFE2E7EE) : const Color(0xFF25313D)),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isLight ? const Color(0xFF1B2630) : darkElevated,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(fontSize: 12, color: Colors.white),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeThroughTransitionBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: _FadeThroughTransitionBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: _FadeThroughTransitionBuilder(),
        },
      ),
    );
  }

  /// Typography tuned for dense security data: headings tightened, body text
  /// opened up, monospace reserved for addresses and hashes.
  static TextTheme _textTheme(ColorScheme scheme) {
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.1,
        color: scheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.15,
        color: scheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        height: 1.2,
        color: scheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
        color: scheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 14.5,
        height: 1.5,
        color: scheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 13.5,
        height: 1.5,
        color: scheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.45,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    );
  }

  /// Monospace for anything the user must read letter-by-letter.
  static TextStyle mono(BuildContext context, {double size = 13}) {
    return TextStyle(
      fontFamily: 'monospace',
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  /// A single uppercase micro-label, used above values across the app.
  static TextStyle overline(BuildContext context) {
    return TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  // ------------------------------------------------------------- mappings

  static Color levelColor(ThreatLevel level) => switch (level) {
    ThreatLevel.safe => safeColor,
    ThreatLevel.suspicious => suspiciousColor,
    ThreatLevel.highRisk => highRiskColor,
  };

  static String levelLabel(ThreatLevel level) => switch (level) {
    ThreatLevel.safe => 'Low risk',
    ThreatLevel.suspicious => 'Suspicious',
    ThreatLevel.highRisk => 'High risk',
  };

  /// One-word verdicts, for the banner headline.
  static String levelWord(ThreatLevel level) => switch (level) {
    ThreatLevel.safe => 'Safe',
    ThreatLevel.suspicious => 'Careful',
    ThreatLevel.highRisk => 'Danger',
  };

  static IconData levelIcon(ThreatLevel level) => switch (level) {
    ThreatLevel.safe => Icons.verified_rounded,
    ThreatLevel.suspicious => Icons.warning_rounded,
    ThreatLevel.highRisk => Icons.dangerous_rounded,
  };

  static IconData typeIcon(ThreatType type) => switch (type) {
    ThreatType.legitimate => Icons.verified_user_rounded,
    ThreatType.spam => Icons.unsubscribe_rounded,
    ThreatType.phishing => Icons.phishing_rounded,
    ThreatType.scam => Icons.price_check_rounded,
    ThreatType.socialEngineering => Icons.psychology_alt_rounded,
  };

  static Color typeColor(ThreatType type) => switch (type) {
    ThreatType.legitimate => legitimateColor,
    ThreatType.spam => spamColor,
    ThreatType.phishing => phishingColor,
    ThreatType.scam => scamColor,
    ThreatType.socialEngineering => socialColor,
  };

  static String typeLabel(ThreatType type) => switch (type) {
    ThreatType.legitimate => 'Likely legitimate',
    ThreatType.spam => 'Spam',
    ThreatType.phishing => 'Phishing',
    ThreatType.scam => 'Scam',
    ThreatType.socialEngineering => 'Social engineering',
  };

  static String typeShortLabel(ThreatType type) => switch (type) {
    ThreatType.legitimate => 'Safe',
    ThreatType.spam => 'Spam',
    ThreatType.phishing => 'Phishing',
    ThreatType.scam => 'Scam',
    ThreatType.socialEngineering => 'Social eng.',
  };

  /// A soft tint of a risk colour, for chip and banner backgrounds.
  static Color tint(Color color, {double alpha = 0.12}) =>
      color.withValues(alpha: alpha);
}

/// Fade + slight scale for pushed routes.
///
/// The Material default slides the whole screen, which is heavy; a short fade
/// with a 2% scale reads faster and lets the destination's own entrance
/// animation stay the focus.
class _FadeThroughTransitionBuilder extends PageTransitionsBuilder {
  const _FadeThroughTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
        child: child,
      ),
    );
  }
}
