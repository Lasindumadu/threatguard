import '../services/hybrid_threat_analyzer.dart';

/// How aggressively ThreatGuard flags messages.
///
/// 2.0 shipped a `strictModeEnabled` setting that was stored and then ignored —
/// it changed nothing. These are the actual thresholds, and they are wired into
/// the analysis path so the setting means something.
///
/// The trade-off is explicit and worth stating to the user:
///
///  * **Relaxed** — fewer alerts. Suited to a user drowning in promotional SMS
///    who mostly wants the obvious scams caught.
///  * **Balanced** — the default. Tuned so legitimate messages are rarely
///    flagged (see the false-positive rate in Model Insights).
///  * **Strict** — catches borderline cases, at the cost of more false alarms.
///    For anyone who would rather check a false alarm than miss a real attack.
enum ProtectionMode {
  relaxed,
  balanced,
  strict;

  String get label => switch (this) {
    ProtectionMode.relaxed => 'Relaxed',
    ProtectionMode.balanced => 'Balanced',
    ProtectionMode.strict => 'Strict',
  };

  String get description => switch (this) {
    ProtectionMode.relaxed => 'Fewer alerts. Only clear threats are flagged.',
    ProtectionMode.balanced =>
      'Recommended. Catches real threats while keeping false alarms low.',
    ProtectionMode.strict =>
      'Most sensitive. Flags borderline messages too, so expect more false '
          'alarms.',
  };

  /// Minimum blended risk score before suspicious-level verdicts are reported.
  int get suspiciousScoreFloor => switch (this) {
    ProtectionMode.relaxed => 30,
    ProtectionMode.balanced => 25,
    ProtectionMode.strict => 15,
  };

  /// Rule score at or above which rule evidence outranks a dissenting model.
  int get strongRuleScore => switch (this) {
    ProtectionMode.relaxed => 60,
    ProtectionMode.balanced => HybridThreatAnalyzer.strongRuleScore,
    ProtectionMode.strict => 40,
  };

  /// Rule score below which a confident model may clear a rule hit.
  int get weakRuleScore => switch (this) {
    ProtectionMode.relaxed => 25,
    ProtectionMode.balanced => HybridThreatAnalyzer.weakRuleScore,
    ProtectionMode.strict => 40,
  };

  /// Confidence the model needs before it may introduce a verdict on its own.
  double get mlOverrideThreshold => switch (this) {
    ProtectionMode.relaxed => 0.85,
    ProtectionMode.balanced => HybridThreatAnalyzer.mlOverrideThreshold,
    ProtectionMode.strict => 0.65,
  };

  /// Confidence the model needs before it may clear a rule hit.
  double get mlDowngradeThreshold => switch (this) {
    ProtectionMode.relaxed => 0.80,
    ProtectionMode.balanced => HybridThreatAnalyzer.mlDowngradeThreshold,
    ProtectionMode.strict => 0.95,
  };

  /// Whether an unsolicited-channel link bonus is applied at all.
  bool get applyChannelRisk => this != ProtectionMode.relaxed;

  // ------------------------------------------------------- escalation weights
  //
  // One table, publicly readable, so "what this changes" in the Shield tab and
  // the analyzer's arithmetic cannot disagree. These are the *only* values that
  // turn a combination of findings into extra risk; each combination is added
  // once, and only when the evidence behind it is present.

  /// Account/security context plus an explicit credential request.
  int get credentialContextEscalation => 8;

  /// A credential request under time pressure.
  int get urgencyCredentialEscalation => 5;

  /// An unexpected prize plus a request for money.
  int get prizeFinancialEscalation => 8;

  /// An unexpected prize plus urgency.
  int get prizeUrgencyEscalation => 4;

  /// Authority + secrecy + urgency + a one-time code request.
  int get highPressureCredentialEscalation => 10;

  /// Authority + secrecy + urgency + a payment request.
  int get highPressureFinancialEscalation => 8;
}
