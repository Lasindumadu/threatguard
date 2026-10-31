import 'package:flutter/material.dart';

/// Visual reference tokens for ThreatGuard.
/// These are intentionally namespaced so they can be adopted selectively.
abstract final class ThreatGuardUiTokens {
  static const Color background = Color(0xFF061326);
  static const Color backgroundRaised = Color(0xFF0A1C33);
  static const Color surface = Color(0xFF102642);
  static const Color surfaceHigh = Color(0xFF163453);
  static const Color border = Color(0xFF244563);

  static const Color primary = Color(0xFF00E5F5);
  static const Color primaryBlue = Color(0xFF168BFF);
  static const Color accent = Color(0xFF8B5CF6);
  static const Color success = Color(0xFF16C79A);
  static const Color warning = Color(0xFFFFB020);
  static const Color danger = Color(0xFFFF4D67);

  static const Color textPrimary = Color(0xFFF3F8FF);
  static const Color textSecondary = Color(0xFFA8BCD2);
  static const Color textMuted = Color(0xFF7189A5);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF168BFF), Color(0xFF00E5D0)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient shieldGradient = LinearGradient(
    colors: [Color(0xFF54F5FF), Color(0xFF168BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(22));
  static const BorderRadius controlRadius = BorderRadius.all(Radius.circular(16));
}
