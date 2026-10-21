# ThreatGuard 3.0 — Cybersecurity Expansion Todo

Legend: `[ ]` pending · `[~]` in progress · `[x]` done & verified

Reference: `docs/EXPANSION_PLAN.md`

## Phase E — Architecture
- [x] E.1 Extend `MessageSource` enum with channel provenance (`whatsapp`, `messenger`, `instagram`, `email`, `web`, `clipboard`, `share`).
- [x] E.2 `ChannelProfile` — per-channel trust weighting + display name.
- [x] E.3 `AppServices` composition root wiring every engine once.
- [x] E.4 `ProtectionMode` enum + thresholds, replacing the inert `strictModeEnabled` flag.
- [x] E.5 Wire `ProtectionMode` into `ThreatAnalyzer` / `HybridThreatAnalyzer`.
- [x] E.6 Persist protection mode + channel toggles.

## Phase C1 — Link scanner (URL forensics)
- [x] C1.1 `UrlForensics` model: registrable domain, subdomains, TLD, scheme, port.
- [x] C1.2 `UrlForensicsAnalyzer` — deep decomposition + risk reasons.
- [x] C1.3 Suspicious-TLD list, shortener map, credential-in-URL detection.
- [x] C1.4 `LinkScannerScreen` UI with highlighted host breakdown.
- [x] C1.5 Unit tests incl. punycode, IP host, shortener, embedded credentials.

## Phase C5 — Impersonation engine
- [x] C5.1 `ImpersonationDetector` — Levenshtein + keyboard-distance + homoglyph normalisation.
- [x] C5.2 Typosquat / combosquat detection (`amaz0n-secure.top`).
- [x] C5.3 Read from the expanded `OrganizationRegistry`.
- [x] C5.4 Surface in link scanner + message detail.
- [x] C5.5 Adversarial unit tests (must not flag the genuine domain).

## Phase C2 — Password audit
- [x] C2.1 `PasswordStrengthAnalyzer` — entropy, char classes, pattern penalties.
- [x] C2.2 Common-password list (offline) + keyboard-walk / date / repeat detection.
- [x] C2.3 `PasswordGenerator` using `Random.secure()` + entropy read-out.
- [x] C2.4 `PasswordAuditScreen` — never persists input, clears on exit.
- [x] C2.5 Unit tests.

## Phase C3 — Breach exposure
- [x] C3.1 `BreachCatalog` bundled data + `BreachRecord` model.
- [x] C3.2 `BreachCheckService` — local first, opt-in online range query.
- [x] C3.3 SHA-1 k-anonymity (only a 5-char prefix leaves the device).
- [x] C3.4 `BreachExposureScreen` with prioritised remediation.
- [x] C3.5 Unit tests for the matcher and prefix-only guarantee.

## Phase B2 — Link interception
- [x] B2.1 `LinkSafety` verdict model (`safe|suspicious|malicious|unknown`).
- [x] B2.2 `LinkSafetyService` — structural + impersonation + reputation.
- [x] B2.3 `QuarantineVault` — flag high-risk URLs, resolve safely.
- [x] B2.4 `LinkInterstitialScreen` — pre-flight warning, deliberate override.
- [x] B2.5 Unit tests.

## Phase B3/B4 — Adaptive protection (added 2026-10-14)
- [x] B3.1 `FeedbackCalibrator` — per-user sensitivity advice from confirmed / false-alarm / missed history, with safety floors (missed threats never steer to Relaxed) + opt-in Shield card.
- [x] B3.2 Unit tests (evidence gate, false-alarm suggestion, missed-threat floor, escalation).
- [x] B4.1 `SecurityAlertService` — sender-window escalation (`SecurityAlert`: "a campaign is targeting you") + Shield campaign-alerts card.
- [x] B4.2 Unit tests (threshold, window expiry).

## Phase A — Universal intake
- [x] A.1 Android `ACTION_SEND` + `PROCESS_TEXT` intent filters.- [x] A.2 Kotlin `ShareIntentHandler` + cold-start routing.
- [x] A.3 Dart `SharedIntakeService` → `ThreatMessage` with channel.
- [x] A.4 `QuickVerdictScreen` — 2-second read, expandable.
- [x] A.5 `ClipboardWatchService` (opt-in).
- [x] A.6 Channel-aware risk weighting.

## Phase C4/C6/C7/C8 — Broader surface
- [x] C4.1 `DevicePostureService` + `PostureCheck` (honest unknowns).
- [x] C4.2 `SecurityPostureScreen` with hygiene score.
- [x] C6.1 `ThreatFeedCatalog` campaign advisories + `ThreatFeedScreen`.
- [x] C7.1 `SecurityTipsEngine` — advice from observed data.
- [x] C8.1 `PermissionAudit` + `VulnerabilitySurfaceScreen` with store justifications.

## Phase D — UI/UX
- [x] D.1 `NavigationBar` → Dashboard · Inbox · Shield · Tools · Settings.
- [x] D.2 `ToolsScreen` index of C1–C8.
- [x] D.3 `ShieldScreen` — protection state, mode selector, quarantine.
- [x] D.4 `CompoundSecurityScore` (message risk + links + hygiene).
- [x] D.5 `SecurityScoreHero` animated gauge.
- [x] D.6 `TimelineChart` custom-painted 7-day sparkline.
- [x] D.7 `VerdictBanner` full-bleed verdict component.
- [x] D.8 Motion: Hero transitions, staggered entrance, haptics.
- [x] D.9 Accessibility pass.

## Phase V — Verification
- [x] V.1 `flutter analyze` clean.
- [x] V.2 Full suite green, expanded for every new engine.
- [x] V.3 `flutter build web` + headless-browser visual verification.
- [x] V.4 Update `docs/AUDIT.md` — real integrations vs. paste paths.
