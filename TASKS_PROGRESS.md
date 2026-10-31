# ThreatGuard — Task Progress Log (Tasks 1 → Current)

**Project root:** `C:\Users\Admin\Desktop\APss\cyber\threatguard`
**Branch:** `task` (ahead of `origin/task` by 1 commit)
**Last commit:** `e1ccd4e task 2.2`
**Working tree:** 9 files modified, unstaged (Task 2.3 in progress)
**Toolchain:** Flutter 3.47.4 / Dart 3.13.3

---

## Task 1.1 — Phase 1.1 Repository Audit and Baseline (COMPLETE)

**Artifact:** `docs/PHASE_1_1_AUDIT.md` (read-only audit, no code changes)

**What was done:**
- Audited the whole repository: toolchain, dependencies, entry points, project structure, subsystems, protection mode, channels, evaluation dataset/split/metrics, documentation accuracy, architecture.
- Ran: `flutter analyze` (clean), `flutter test` (411 pass, 3 fail, 1 skipped), targeted suites (all pass).
- Identified 3 pre-existing test failures (stale metric floors): 2 held-out model errors instead of 1, 1 rule-engine type error (`social_018`). Declared out of scope for 1.1.
- Found key architectural issues:
  - Production classifier (`AppServices._build()` / `ThreatEngine._build()`) trains on all 105 cases, while Model Insights reports "held-out" metrics from a model trained on 70 — live model saw its own test fold.
  - Online lookup gated but composition only registers `UnavailableOnlineUrlReputationProvider` — opting in can never reach network.
  - `LocalStore.enabledChannels` turns stored empty list back into "all channels" — all-off not durable.
  - `falsePositiveRate` computes legitimate FN rate (misses), not FP rate; name/doc disagree.
  - `threatPrecision` pools all threat classes; docs quote as per-class truth.
  - `ProtectionMode.mlDowngradeThreshold` defined but never read.
  - `docs/AUDIT.md` has two contradictory metric tables + stale "strict mode inert" claim + "365 tests pass" claim now false.

**Outcome:** Recommended ordered Task 1.2 (restore trustworthy baseline). Stopped there as instructed.

---

## Task 1.2 — Restore a Trustworthy Baseline (COMPLETE)

**Commit:** `6187d10 Improve threat detection and configure release signing`

**Changes:**
- `lib/core/services/text_matcher.dart` — word-boundary / punctuation-aware matching (fixed B6 substring false positives: `'pin'` no longer matches "shipping"/"spin"/"opinion").
- `lib/core/services/url_analyzer.dart` — URL forensics hardening.
- `lib/core/services/threat_analyzer.dart` — threat detection improvements.
- `lib/core/services/ml_dataset_splitter.dart` — splitter fixes.
- `lib/core/models/url_analysis.dart` — minor model fix.
- Android release signing configured (`android/app/build.gradle.kts`, `AndroidManifest.xml`, `.gitignore`).
- `README.md` updated.
- Tests: `test/ml_dataset_splitter_test.dart`, `test/text_matcher_test.dart`, `test/threat_analyzer_test.dart`, `test/url_analyzer_test.dart` added/updated.
- Removed stray `test_results.txt` (69 KB).

**Tests added:** text_matcher (44 new), url_analyzer (175 new), threat_analyzer (21 new), ml_dataset_splitter (79 updated).

---

## Task 1.3.x — Hardening SMS and Threat Analysis Flows (COMPLETE)

**Commit:** `80b6b81 task 1.3.3` — 133 files, +28110 / −2051 lines

This was a large modernization pass implementing most of the Expansion Plan and Improvement Plan:

**New models:**
- `breach_record.dart`, `campaign_advisory.dart`, `channel_profile.dart`, `hybrid_threat_analysis.dart`, `local_settings_snapshot.dart`, `message_source.dart`, `ml_dataset_split.dart`, `ml_prediction.dart`, `protection_mode.dart`, `security_posture.dart`, `sender_analysis.dart`, `threat_analysis.dart`, `threat_signal.dart`

**New services:**
- `app_services.dart` (composition root), `breach_check_service.dart`, `clipboard_watch_service.dart`, `composite_url_reputation_provider.dart`, `compound_security_score.dart`, `feedback_calibrator.dart`, `hybrid_threat_analyzer.dart`, `impersonation_detector.dart`, `link_safety_service.dart`, `local_store.dart`, `logistic_regression_classifier.dart`, `ml_dataset_splitter.dart`, `ml_feature_extractor.dart`, `model_evaluation.dart`, `organization_registry.dart`, `password_strength_analyzer.dart`, `security_alert_service.dart`, `security_tips_engine.dart`, `sender_analyzer.dart`, `shared_intake_service.dart`, `signal_features.dart`, `sms_threat_analyzer.dart`, `template_fingerprint.dart`, `text_matcher.dart`, `text_preprocessor.dart`, `threat_analyzer.dart`, `threat_engine.dart`, `threat_rule_catalog.dart`, `threat_trend.dart`, `url_extractor.dart`, `url_forensics_analyzer.dart`, `url_input.dart`, `verdict_policy.dart`

**UI:**
- `app_theme.dart` (light + dark, risk palette), `motion.dart`, `threat_widgets.dart`
- Screens: analyzer, dashboard, model_insights, quick_verdict, settings, home_shell (5-tab), link_interstitial, shield, sms inbox/detail, breach_exposure, link_scanner, password_audit, permission_surface, security_posture, security_tips, threat_feed, tools
- Android: `MainActivity.kt` (share-sheet `ACTION_SEND` + `PROCESS_TEXT`), `AndroidManifest.xml`

**Tests added:** app_services, breach_check_service, channel_and_protection, impersonation_detector, link_safety_service, model_evaluation, password_strength_analyzer, phase1_regression, protection_feedback, protection_mode_pipeline, security_surface, template_fingerprint, threat_diagnostic, url_extractor, url_forensics_analyzer, url_threat_evaluation, verdict_consistency, widget_test

**Docs:** `docs/AUDIT.md`, `docs/EXPANSION_PLAN.md`, `docs/IMPROVEMENT_PLAN.md`, `docs/TODO.md`, `docs/completion.txt`, `docs/PHASE_1_1_AUDIT.md`

**Sub-projects:** `.tmp_probe/` (probe tests), `.tmp_uiux/` (UI/UX audit + design system + admin dashboard React app)

**Verified at that point:** `flutter analyze` clean, `flutter test` → 365 pass, `flutter build web --release` builds, headless browser 0 console errors.

---

## Task 2.2 — ML Evaluation Dataset: Scenario Families + Group-Aware Split (COMPLETE)

**Commit:** `e1ccd4e task 2.2` (HEAD)

**Files changed:** 8 files, +1022 / −2 lines

**Changes:**
- `lib/core/models/evaluation_case.dart` — added optional `scenarioFamily` field to `EvaluationCase`.
- `lib/core/models/ml_feature_vector.dart` — added `scenarioFamily` field to `MlFeatureVector`.
- `lib/core/models/ml_dataset_split.dart` — split result model.
- `lib/core/services/evaluation_dataset.dart` — 105 cases; 86 assigned to 20 named scenario families, 19 left as null-family singletons. Families documented in header comment (legit, spam, phishing, scam, social engineering families).
- `lib/core/services/ml_dataset_splitter.dart` — added `splitGroupedThreeWay(seed, devFraction, testFraction)`: keeps all members of a scenario family in the same fold, preventing near-duplicate template leakage between train and held-out. Atomic families; class coverage preserved in training.
- `lib/core/services/ml_feature_extractor.dart` — passes `scenarioFamily` through to `MlFeatureVector`.
- `lib/core/services/ml_training_dataset.dart` — passes `scenarioFamily` through.
- `test/ml_dataset_splitter_grouped_test.dart` — 609 lines of tests for grouped split.

**Verified:** `splitGroupedThreeWay` with seed 1337 → TRAIN 56 / DEV 26 / TEST 23 (confirmed). Group-aware split ensures no family straddles folds.

---

## Task 2.3 — ML Pipeline: 29th Feature + Benign-Context Arbitration + Local URL Reputation (IN PROGRESS)

**Status:** Unstaged working-tree changes, 9 files, +62 / −9 lines

**Changes:**

1. **`lib/core/models/ml_feature_vector.dart`** — Added 29th boolean feature `hasAccountVerificationUrlPattern` (account verification language + URL present). Added constructor parameter.

2. **`lib/core/services/ml_feature_extractor.dart`** — Computes `hasAccountVerificationUrlPattern = hasAccountVerificationLanguage && hasUrl`; passes it into `MlFeatureVector`.

3. **`lib/core/services/ml_feature_encoder.dart`** — Encodes the new bool as the 29th numeric value. Encoder output is now 29 values (was 28).

4. **`lib/core/services/hybrid_threat_analyzer.dart`** — Moved `benignReason` computation earlier (before `_resolveFinalType`). Added `benignReason` parameter to `_resolveFinalType`. When rule engine finds no threat AND a strong benign reason exists (security advice, transaction notification, delivery update), ML is **not permitted** to override — returns legitimate with explicit rationale. This prevents the model from overriding a deliberate, explainable rule-engine safe determination.

5. **`lib/core/services/local_url_reputation_provider.dart`** — Replaced naive IPv4 regex (`^(?:\d{1,3}\.){3}\d{1,3}$`) with rigorous validation: exactly 4 dot-separated parts, each non-empty, each parseable as int 0–255. Rejects leading zeros implicitly via `int.tryParse` on canonical forms, rejects empty parts, rejects wrong part count.

6. **`lib/core/services/threat_analyzer.dart`** — Prize pattern rule: added `!context.hasUrl` guard so a message with a prize pattern AND a URL is not auto-classified as spam/legitimate via the prize-only path (prevents prize+URL phishing from being misclassified).

7. **`lib/core/models/threat_analyzer.dart`** (test support) — `test/ml_dataset_splitter_grouped_test.dart`, `test/ml_feature_distribution_diagnostic_test.dart`, `test/ml_feature_encoder_test.dart` — updated for 29 features: added `hasAccountVerificationUrlPattern: false` to test fixtures, added to expected feature name list, added switch case in `_getBooleanFeature`, encoder test updated from 28→29 expected values.

**Not yet committed.** Tests need to be run to confirm green.

---

## Pre-Existing Issues (Out of Scope — Not Caused by Current Work)

Three test failures existed before current work began (documented in `docs/PHASE_1_1_AUDIT.md` §8.1):
- `test/hybrid_threat_evaluation_test.dart`: `ruleCorrect >= 35` → actual 34
- `test/hybrid_threat_diagnostic_test.dart`: `finalCorrectCount == 35` → actual 34
- `test/logistic_regression_error_analysis_test.dart`: `errorCount == 1` → actual 2

Root cause: 2 held-out model errors (`phishing_001` → socialEngineering, `scam_001` → legitimate) + 1 rule-engine type error (`social_018`). Declared out of scope; not touched by Tasks 1.2–2.3.

---

## Key Architecture Facts

- **Classifier:** Hand-written logistic regression over boolean features (no TFLite/ML package). Now 29 boolean features.
- **Dataset:** 105 hand-written evaluation cases (legitimate 21, spam 21, phishing 21, scam 21, social engineering 21).
- **Split:** Legacy `splitThreeWay` (class-stratified, 70/14/21) vs new `splitGroupedThreeWay` (family-aware, 56/26/23 with seed 1337).
- **Hybrid arbitration:** Rules first; ML can override only when sufficiently confident and decisive; benign context can block ML override entirely (Task 2.3).
- **Persistence:** `LocalStore` (SharedPreferences) for protection mode, channels, theme, online lookup, muted senders, feedback.
- **Channels:** SMS (auto-read), WhatsApp/Messenger/Instagram/Email/Web/Clipboard/Manual/Shared (share-sheet intake only — no automatic read API for E2E-encrypted apps).
- **Online lookup:** `CompositeUrlReputationProvider` with `UnavailableOnlineUrlReputationProvider` stub — Web Risk provider exists but is not registered in production composition (known gap).
- **Entry points:** `lib/main.dart` → `AppServices.instance` → `HomeShell` (5-tab: Dashboard, Inbox, Shield, Tools, Settings). Android share-sheet via `MainActivity.kt`.
