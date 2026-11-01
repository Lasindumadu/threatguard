import 'package:flutter/material.dart';

class ThreatGuardUiTokens {
  const ThreatGuardUiTokens._();

  static const Color primary = Color(0xFF20D9F3);
  static const Color surface = Color(0xFF111A2C);
  static const Color border = Color(0xFF2B3E59);
  static const Color background = Color(0xFF080D19);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF20D9F3), Color(0xFF0083B0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient shieldGradient = LinearGradient(
    colors: [Color(0xFF1C2C42), Color(0xFF111A2C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
