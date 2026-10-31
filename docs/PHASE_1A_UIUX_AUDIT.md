ThreatGuard Phase 1A UI/UX Audit & Design Foundation

Overview
- Phase 1A establishes a premium visual direction and a reusable design token system without restructuring architecture or breaking security logic.

What I inspected
- Project structure and Flutter architecture under lib/: main.dart, lib/core/, lib/features/ (dashboard, shield, sms, tools, settings, intake, analyzer, insights), lib/core/theme/app_theme.dart, lib/core/widgets, lib/core/models, lib/core/services.
- Screens (high-level):
  - 5-tab shell (Dashboard, Inbox, Shield, Tools, Settings) and screens: DashboardScreen, SmsInboxScreen, SmsDetailScreen, ShieldScreen, ToolsScreen, LinkScannerScreen, PasswordAuditScreen, BreachExposureScreen, SecurityPostureScreen, ThreatFeedScreen, ModelInsightsScreen, AnalyzerScreen, SettingsScreen, QuickVerdictScreen, VerdictBanner, etc.
- Tokens & design language references in AppTheme (core/theme/app_theme.dart) and the current threat color ramps (safe, suspicious, high risk, critical).
- Assets: none custom assets; relies on Material icons.
- Tests: test/widget_test.dart validates UI navigation, presence of screens, and theme tokens; other tests around threat engine and URL safety exist under test/.

Key findings
- The current UI has a cohesive “deep navy + cyan highlights + violet accents” intent, but lacks a centralized design token source for future Phase 2 upgrade.
- Reusable components exist (SectionCard, RiskGauge, TypeBadge, TimelineChart, etc.) but tokens aren’t centralized, which will slow upgrade.
- No breaking changes to architecture were needed in Phase 1; the app remains fully functional with the current UI and threat engine.

Design direction (premium visuals for Phase 2)
- A premium cybersecurity aesthetic using: deep navy surfaces, cyan/teal highlights, violet accents, subtle gradients, elegant typography, and consistent spacing.
- Maintain accessibility: ensure contrast for risk colors (safe/suspicious/high/critical) and text on dark surfaces.

Design tokens introduced in Phase 1A
- lib/core/theme/app_design.dart (new)
  - AppDesign: a lightweight design token container with brand colors, gradients, surface colors, spacing, and radii.
  - Tokens are intentionally non-invasive: they do not alter AppTheme at runtime but serve as a foundation for future migration.

Implementation changes in this phase
- Added a minimal design tokens file for Phase 2 evolution:
  - lib/core/theme/app_design.dart with: brandSeed, brandAccent, brandNavy, brandNavyCard, accentViolet, accentVioletTint, gradients, surface colors, spacing values, radii.
- This is deliberately small and non-disruptive to existing UI, APIs, and security logic.

Potential impact on security features
- Visual updates must not alter the risk semantics, color mappings, or contrast in a way that could obscure high-risk indicators.
- Do not introduce gradient-based emphasis on critical warnings without ensuring legibility on all themes.
- Avoid changing fonts or weights for labels that are used in critical risk indicators to preserve readability.

Next-phase plan (Phase 1B → Phase 2)