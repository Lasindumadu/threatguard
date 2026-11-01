import 'package:flutter/material.dart';

/// Cyber-Glassmorphic Neon Color Presets & Skins
enum AppSkin {
  cyan(
    id: 'cyan',
    name: 'Cyber Cyan',
    primary: Color(0xFF00B8D4),
    glow: Color(0xFF00F0FF),
    surface: Color(0xFF0B1218),
    card: Color(0xFF141D26),
    elevated: Color(0xFF1B2630),
    border: Color(0xFF25313D),
    gradientStart: Color(0xFF0E141B),
    gradientEnd: Color(0xFF101822),
  ),
  crimson(
    id: 'crimson',
    name: 'Neon Crimson',
    primary: Color(0xFFFF2A5F),
    glow: Color(0xFFFF4B7D),
    surface: Color(0xFF140A0F),
    card: Color(0xFF1F1218),
    elevated: Color(0xFF2A1922),
    border: Color(0xFF3D202D),
    gradientStart: Color(0xFF160D12),
    gradientEnd: Color(0xFF1F1018),
  ),
  emerald(
    id: 'emerald',
    name: 'Cyber Emerald',
    primary: Color(0xFF00F59B),
    glow: Color(0xFF3B82F6),
    surface: Color(0xFF081410),
    card: Color(0xFF0F1E19),
    elevated: Color(0xFF162923),
    border: Color(0xFF223D33),
    gradientStart: Color(0xFF0A1813),
    gradientEnd: Color(0xFF0D221B),
  ),
  violet(
    id: 'violet',
    name: 'Cyber Violet',
    primary: Color(0xFF8B5CF6),
    glow: Color(0xFFA855F7),
    surface: Color(0xFF0F0C1B),
    card: Color(0xFF181329),
    elevated: Color(0xFF231B38),
    border: Color(0xFF352952),
    gradientStart: Color(0xFF130E22),
    gradientEnd: Color(0xFF1A132E),
  );

  final String id;
  final String name;
  final Color primary;
  final Color glow;
  final Color surface;
  final Color card;
  final Color elevated;
  final Color border;
  final Color gradientStart;
  final Color gradientEnd;

  const AppSkin({
    required this.id,
    required this.name,
    required this.primary,
    required this.glow,
    required this.surface,
    required this.card,
    required this.elevated,
    required this.border,
    required this.gradientStart,
    required this.gradientEnd,
  });

  static AppSkin fromId(String? id) {
    for (var skin in AppSkin.values) {
      if (skin.id == id) return skin;
    }
    return AppSkin.cyan;
  }
}
