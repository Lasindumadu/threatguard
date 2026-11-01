// ThreatGuard Design Tokens — Foundation for Phase 2 UI/UX Upgrade
//
// Lightweight, design-token file intended for Phase 1 foundation. This file
// provides semantic tokens that future UI work can consume. It avoids any
// runtime theme changes and keeps current architecture intact.

import 'package:flutter/material.dart';

class AppDesign {
  const AppDesign._();

  // Brand
  static const Color brandSeed = Color(0xFF0E4C63);
  static const Color brandAccent = Color(0xFF00B8D4);
  static const Color brandNavy = Color(0xFF071118);
  static const Color brandNavyCard = Color(0xFF0F1A24);

  // Accent / tertiary
  static const Color accentViolet = Color(0xFF7C5CFF);
  static Color accentVioletTint([double a = 0.12]) =>
      accentViolet.withValues(alpha: a);

  // Gradients and hero surfaces
  static const Color gradientLightStart = Color(0xFFEFF6FF);
  static const Color gradientLightEnd = Color(0xFFFAFAFF);
  static const Color gradientDarkStart = Color(0xFF0B1218);
  static const Color gradientDarkEnd = Color(0xFF101822);
  static const Color gradientHeroLightStart = Color(0xFFFFFFFF);
  static const Color gradientHeroLightEnd = Color(0xFFF0F5F9);
  static const Color gradientHeroDarkStart = Color(0xFF16232E);
  static const Color gradientHeroDarkEnd = Color(0xFF101820);

  // Risk palette (kept for reference; AppTheme provides actual usage)
  static const Color riskSafe = Color(0xFF12996B);
  static const Color riskSuspicious = Color(0xFFE08A00);
  static const Color riskHigh = Color(0xFFE0384C);
  static const Color riskCritical = Color(0xFF9B1B30);
  static const Color riskUnknown = Color(0xFF64748B);

  // Surface colors
  static const Color surfaceLight = Color(0xFFF4F6F9);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E7EE);
  static const Color mutedLight = Color(0xFF5A6472);

  static const Color surfaceDark = Color(0xFF0B1218);
  static const Color cardDark = Color(0xFF141D26);
  static const Color elevatedDark = Color(0xFF1B2630);
  static const Color borderDark = Color(0xFF25313D);
  static const Color mutedDark = Color(0xFF93A2B3);

  // Spacing tokens (4px grid)
  static const double spaceXxs = 4.0;
  static const double spaceXs = 8.0;
  static const double spaceSm = 12.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;
  static const double spaceXxl = 48.0;
  static const double spaceXxxl = 80.0;

  // Radii
  static const double radiusSm = 10.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 22.0;
  static const double radiusXl = 28.0;
}
