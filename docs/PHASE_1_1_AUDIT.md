# ThreatGuard — Phase 1.1 Repository Audit and Baseline

_Read-only audit. No application code, test, dependency or configuration was
modified. Any number below was produced by a command that ran on this machine
during this audit; anything not run is explicitly listed as not run._

Date: 2026-10-21 · Project root: `C:\Users\Admin\Desktop\APss\cyber\threatguard`

---

## 0. Executive summary

| Question | Answer |
|---|---|
| Does the project build/analyse cleanly? | `flutter analyze` → **No issues found** (0 errors, 0 warnings, 0 lints). |
| Does the test suite pass? | **No.** 411 pass, **3 fail**, 1 skipped (reported as `+411 -3 ~1`). Total runtime ≈ 80 s. |
| Is Strict/Balanced/Relaxed wired into analysis? | **Yes, partly.** The rule engine reads mode thresholds and escalation weights; the arbitration thresholds and the channel bonus are also mode-dependent. One documented threshold (`mlDowngradeThreshold`) is mode-derived but **never read** in the arbitration path. |
| Are enabled channels enforced? | **Yes for automatic analysis, no for intake.** `analyzeMessage` refuses disabled channels; user-initiated text/share intake is deliberately not gated. Channel toggles gate nothing else (inbox reading is tied to SMS only). |
| Is the evaluation honest? | **Mostly, with a serious weakness.** Train/test are separated by ID, but both folds come from one 105-case hand-written list; every case is a "family" of one, so the held-out set is not held out against near-duplicates. |
| Are the docs accurate? | **Partly outdated.** `docs/AUDIT.md` claims numbers that no longer match the code or the suite; README's project structure is stale. Details in §6. |
| Biggest risk found | **`AppServices._build()` (the path `main.dart` actually uses, including in tests) trains the production classifier on all 105 evaluation cases, including the 21 that the Model Insights screen and the model tests report as held out, and that path can never use the online link-reputation provider.** Details in §7.1 and §7.2. |

---

## 1. Environment and entry points

### 1.1 Toolchain (verified)

```
flutter --version
Flutter 3.47.4 • channel stable • revision 9584c6713b (2026-09-10)
Tools • Dart 3.13.3 • DevTools 2.60.0
```

`pubspec.yaml` declares `environment: sdk: ^3.13.3`, `version: 1.0.0+1`.
README's "Development Environment" section (Flutter 3.47.4 / Dart 3.13.3) matches
the installed toolchain.

### 1.2 Dependencies (unchanged, not upgraded)

| Package | Constraint | Role |
|---|---|---|
| `flutter`, `flutter_localizations` | SDK | UI, localisation delegates |
| `cupertino_icons` | ^1.0.8 | icons |
| `shared_preferences` | ^2.3.3 | all persistence (`LocalStore`) |
| `crypto` | ^3.0.6 | SHA-1 for breach k-anonymity prefix |
| `http` | ^1.2.2 | opt-in online lookup / breach query only |
| `flutter_test` | SDK (dev) | tests |
| `flutter_lints` | ^6.0.0 (dev) | lints |

No ML/TFLite package: the classifier is hand-written Dart
(`logistic_regression_classifier.dart`). No state-management package: plain
`ValueNotifier` + `StatefulWidget`.

### 1.3 Application entry points

| Entry point | Path | Notes |
|---|---|---|
| Dart entry | `lib/main.dart` → `main()` → `runApp(const ThreatGuardApp())` | `main()` builds `AppServices.instance`, an `InboxController`, then `_loadStore()` hydrates settings via `AppServices.applyPersistedSettings(...)`. Root widget is `HomeShell`. |
| Android entry | `android/app/src/main/kotlin/lk/lasindu/threatguard/MainActivity.kt` | Share-sheet `ACTION_SEND` / `PROCESS_TEXT` intake. |
| Process-wide singletons | `AppServices.instance` (`_build()`), `ThreatEngine.instance` (`_build()`), `LocalStore.load()` | Two independent engine builders exist — see §7.1. |

### 1.4 Actual project structure (verified on disk)

```text
threatguard/
├── analysis_options.yaml            # flutter_lints
├── pubspec.yaml / pubspec.lock
├── README.md                        # project structure section is stale (§6)
├── test_results.txt                 # stray committed test log (69 KB)
├── hs_err_pid*.log                  # 3 stray JVM crash logs at repo root
├── android/  ios/  linux/  macos/  web/  windows/   # platform shells
├── docs/  AUDIT.md  TODO.md  EXPANSION_PLAN.md  IMPROVEMENT_PLAN.md
├── prompts/  .kilo/  .kilocode/  .tmp_probe/  .tmp_uiux/   # not app code
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── models/         20 files (threat_analysis, hybrid_threat_analysis, protection_mode, …)
│   │   ├── services/       51 files (§2)
│   │   ├── theme/          app_theme.dart
│   │   └── widgets/        threat_widgets.dart
│   └── features/
│       ├── shell/          home_shell.dart (5-tab navigation)
│       ├── dashboard/      dashboard_screen.dart
│       ├── sms/            application/inbox_controller.dart, presentation/screens/*
│       ├── shield/         shield_screen.dart, link_interstitial_screen.dart
│       ├── intake/         quick_verdict_screen.dart
│       ├── analyzer/       analyzer_screen.dart
│       ├── insights/       model_insights_screen.dart
│       ├── settings/       settings_screen.dart
│       └── tools/          tools_screen + link_scanner, breach, password, posture,
│                           permissions, tips, threat_feed
└── test/                   51 files
```

Git is present; the working tree was audited as-is.

---

## 2. Where each subsystem lives

| Subsystem | File(s) | Key symbols |
|---|---|---|
| **Analysis engine (orchestration)** | `core/services/threat_engine.dart` | `ThreatEngine`, `MessageThreatReport`, `_report` (cache), `_notAnalysed`, `analyzeMessage` (gated), `analyzeText` (not gated), FNV-1a `_fingerprint`, 500-entry cache, cache key `source␁mode␁id` |
| **Rule detector** | `core/services/threat_analyzer.dart`, `threat_rule_catalog.dart`, `signal_features.dart`, `text_matcher.dart`, `text_preprocessor.dart` | `ThreatAnalyzer.analyze(String?, {ProtectionMode})`, `ThreatRuleCatalog.rules`, `SignalFeatures.extract`, `TextPreprocessor.normalize/bound/capTokenLength/matchingForm` |
| **ML classifier** | `core/services/logistic_regression_classifier.dart`, `ml_classifier.dart`, `ml_feature_extractor.dart`, `ml_feature_encoder.dart`, `ml_training_dataset.dart`, `majority_class_classifier.dart` | `LogisticRegressionClassifier.train/predict`, `MlFeatureExtractor.extract`, `MlTrainingDataset.build` |
| **Hybrid decision** | `core/services/hybrid_threat_analyzer.dart`, `verdict_policy.dart` | `HybridThreatAnalyzer.analyze/_resolveFinalType`, `VerdictPolicy.assemble/benignContext/applyBenignContext/levelFor/unavailable` |
| **URL forensics** | `core/services/url_forensics_analyzer.dart`, `impersonation_detector.dart`, `url_extractor.dart`, `url_analyzer.dart`, `url_input.dart`, `local_url_reputation_provider.dart`, `composite_url_reputation_provider.dart`, `google_web_risk_*` | `UrlForensicsAnalyzer`, `ImpersonationDetector`, `LinkSafetyService` (`link_safety_service.dart`) |
| **Organization registry** | `core/services/organization_registry.dart`, `organization_url_analyzer.dart`, `sender_analyzer.dart` | `OrganizationRegistry().profiles`, `OrganizationUrlAnalyzer`, `SenderAnalyzer.isCheckableShortCode` |
| **Result models** | `core/models/threat_analysis.dart`, `hybrid_threat_analysis.dart`, `threat_signal.dart`, `ml_prediction.dart`, `sender_analysis.dart`, `url_*.dart`, `threat_message.dart`, `channel_profile.dart` | `ThreatAnalysis`, `HybridThreatAnalysis`, `EvidenceConfidence`, `ThreatIndicator.identity` |
| **Persistence** | `core/services/local_store.dart`, `core/models/local_settings_snapshot.dart` | `LocalStore` (SharedPreferences), `settingsSnapshot`, `enabledChannels`, `setEnabledChannels` |
| **Channel settings** | `core/models/message_source.dart`, `channel_profile.dart`; `features/shield/presentation/screens/shield_screen.dart`; `features/shell/.../home_shell.dart` (`_setEnabledChannels`) | `MessageSource` enum, `ChannelProfile`, `AppServices.enabledChannels` |
| **Clipboard service** | `core/services/clipboard_watch_service.dart`; wired in `home_shell.dart` (`_syncClipboardWatcher`) | `ClipboardWatchService(isActive/_poll/pollNowForTest/reset)`, `ClipboardSuggestion` |
| **Navigation** | `features/shell/presentation/screens/home_shell.dart` | 5 tabs: Dashboard · Inbox · Shield · Tools · Settings; `IndexedStack`/`NavigationBar` |
| **Composition root** | `core/services/app_services.dart` | `AppServices._build`, `applyPersistedSettings`, `setOnlineLookupEnabled`, `setClipboardWatchEnabled` |
| **Tests** | `test/*.dart` (51 files) | see §5 |

---

## 3. Protection mode (Strict / Balanced / Relaxed)

### 3.1 Where it is configured

1. `core/models/protection_mode.dart` — the enum **and** the numeric thresholds
   (`suspiciousScoreFloor`, `strongRuleScore`, `weakRuleScore`,
   `mlOverrideThreshold`, `mlDowngradeThreshold`, `applyChannelRisk`, and the six
   escalation weights).
2. `features/shield/presentation/screens/shield_screen.dart` — `SegmentedButton`,
   the threshold panel, and `ChannelAdvice` → "Use Strict".
3. `features/shell/.../home_shell.dart` — `_setProtectionMode()` writes
   `services.protectionMode.value` and `store.setProtectionMode()`.
4. `core/services/local_store.dart` — key `protection_mode` (+ legacy
   `strict_mode_enabled` kept in sync).
5. `lib/main.dart` — hydration on cold start via `applyPersistedSettings(mode: …)`.

### 3.2 Does it actually change analysis? (verified by reading the call chain)

```text
AppServices.protectionMode (ValueNotifier)
  └─ listener → ThreatEngine.setMode()  → clears cache
       └─ ThreatEngine._analyze → HybridThreatAnalyzer.analyze(message, mode:)
            ├─ ThreatAnalyzer.analyze(..., mode:)  → _ThreatContext.build(mode:)   ✔
            │     · score += mode.<escalation>* when the combo is present
            │     · level: score >= mode.suspiciousScoreFloor
            │     · strict-only promotion of suspicious borderline cases
            └─ _resolveFinalType(mode:) → mode.strongRuleScore / mlOverrideThreshold  ✔
       └─ VerdictPolicy.assemble(mode:) → channel bonus unless relaxed                ✔
```

**Verdict: the mode is behaviourally live**, not a stored label. Covered by
`test/channel_and_protection_test.dart` ("actually changes detection"), which
passes.

### 3.3 Caveat found (not a blocker, but a documentation/implementation gap)

- `ProtectionMode.mlDowngradeThreshold` is defined for all three modes and is
  presented in the code as a live threshold, but a repository-wide grep finds
  **no reader** of it in the arbitration path. Only `mlOverrideThreshold`,
  `strongRuleScore`, `weakRuleScore`, `suspiciousScoreFloor` and
  `applyChannelRisk` are consumed. The Shield panel shows "Model confidence to
  decide alone" (override) and "Rule evidence that outranks the model" — it does
  **not** display the unused downgrade threshold, so the UI does not overclaim.
  Status: dead public API; should be either wired or removed in a later task.

---

## 4. Channels: storage and enforcement

### 4.1 Storage

| Layer | Location | Behaviour |
|---|---|---|
| Enum | `core/models/message_source.dart` | The set of channels. |
| Raw storage | `LocalStore` key `enabled_channels` (`stringList` of `MessageSource.name`) | `get enabledChannels` → `raw == null \|\| raw.isEmpty` ⇒ **all channels**; names not in this build are dropped; **if nothing known remains, returns all channels** (documented as "unset, not all-off"). |
| Parsed snapshot | `LocalSettingsSnapshot.channels` | Returns `null` when unset, else only known names; an empty set here means "all known names were junk". |
| Live state | `AppServices.enabledChannels` (`ValueNotifier<Set<MessageSource>>`), default = all | Single owner; listener pushes into `ThreatEngine.setEnabledChannels`, which clears the cache on real change. |
| UI | `ShieldScreen` "Monitored channels" switches; `home_shell._setEnabledChannels` persists + `_syncClipboardWatcher()` | — |

### 4.2 Enforcement (verified)

| Path | Gated by channel toggles? | Evidence |
|---|---|---|
| `ThreatEngine.analyzeMessage` (automatic) | **Yes** — returns an explicit *not analysed* report (`VerdictPolicy.unavailable`) | `threat_engine.dart` lines 167-180, 251-267 |
| `ThreatEngine.analyzeText` (pasted / shared / manual) | **No, by design** — the user asked for an answer; the channel still contributes risk | `threat_engine.dart` lines 182-216 |
| `ThreatEngine.analyzeAll` (Shield/inbox batch) | Yes, via `analyzeMessage` | — |
| Clipboard watcher | **Yes** — needs *both* consent (`clipboardWatchEnabled`) and `MessageSource.clipboard`; checked on `start`/`stop` and on every poll | `home_shell.dart` 78-105, 143-153; `clipboard_watch_service.dart` 78-81, 170-179 |
| SMS inbox read | Only indirectly: `InboxController.smsChannelEnabled` gates `loadMessages()` | `inbox_controller.dart` 77-118, 155-157 |
| Shared-intake / Quick Verdict | Not gated; the UI is told when the source channel is off (`home_shell.dart` ~199) | — |

**Residual issue:** `LocalStore.setEnabledChannels(set)` writes the empty list
`[]` when every channel is off, but `LocalStore.enabledChannels` maps `[]` back
to *all channels* (the same branch as "key absent"). So "monitor nothing" is not
durable: after a restart every channel is monitored again. `LocalSettingsSnapshot` does not have this
bug (empty list ⇒ empty set). This is a persistence asymmetry worth listing in a
later task; it is not covered by the current suite.

---

## 5. Evaluation dataset, split, and metrics

### 5.1 Data

- `core/services/evaluation_dataset.dart` — `EvaluationDataset.cases`: a single
  hand-written list (the current suite reports **105** cases:
  legitimate 21, spam 21, phishing 21, scam 21, social engineering 21).
- `MlTrainingDataset.build()` maps **every** case in that list to an
  `MlTrainingExample` (features + label). There is no separate training corpus.
- Separate URL datasets: `url_evaluation_dataset.dart`,
  `url_threat_evaluation_dataset.dart`, models `url_evaluation_case.dart`,
  `url_threat_evaluation_case.dart`.

### 5.2 Split

`MlDatasetSplitter.splitThreeWay(examples, seed: 1337, devFraction: 0.15,
testFraction: 0.20)`:
- groups by class, sorts by `caseId`, shuffles deterministically per class
  (LCG seeded `seed + class.index`),
- per class: `test = round(n*0.20)` (≥1 if n≥3), `dev = round(n*0.15)` (≥1 if n≥5),
  remainder = train, never emptying the class.
- `split()` / `splitShuffled()` are the older two-way variants; `_splitByGroups`
  uses a hard-coded 0.33 test fraction (legacy).

With 105 cases the actual split is **70 train / 14 dev / 21 test** (confirmed by
`test/model_evaluation_test.dart` output).

### 5.3 Metrics

`core/services/model_evaluation.dart`:
- `ClassMetrics.precision = TP/(TP+FP)`, `recall = TP/(TP+FN)`, `f1 = harmonic mean`;
- `ModelEvaluationReport.accuracy`, `macroF1`, `macroPrecision`, `macroRecall`,
  `threatPrecision` (micro over all non-legitimate classes),
  `falsePositiveRate` (**defined here as legitimate FN / legitimate support**, i.e.
  *missed legitimate messages*, not "legitimate flagged as a threat" — the getter's
  name contradicts its own doc comment at line 100-101; `test/model_evaluation_test.dart`
  contains a test named "false-positive rate counts legitimate messages flagged as
  threats" that passes because it asserts the current implementation for a
  fully-correct row, so it does **not** actually discriminate);
- `threatPrecision` pools every non-legitimate class, so a `phishing` predicted
  as `scam` counts as a TP (it was flagged as a threat) — the headline number
  says nothing about *which* threat class was chosen. That is defensible as a
  "did we see a threat at all" metric, but the docs quote it as if it were the
  per-class precision.
- `ModelEvaluator.evaluate({actual, predicted, datasetLabel})` builds the report;
  `toReportString()` is what tests and `ModelInsightsScreen` print/render.

### 5.4 Baseline model numbers measured during this audit

`flutter test test/model_evaluation_test.dart` (seed 1337, held-out fold):

```
Samples:        21
Accuracy:       95.2%
Macro F1:       95.3%
False-positive rate 0.0%
  legitimate           P 83.3%  R 100.0%  F1 90.9%  (n=5)
  spam                 P 100.0%  R 100.0%  F1 100.0% (n=4)
  phishing             P 100.0%  R 100.0%  F1 100.0% (n=4)
  scam                 P 100.0%  R  75.0%  F1  85.7%  (n=4)
  social engineering   P 100.0%  R 100.0%  F1 100.0% (n=4)
```

Single error: one `scam` predicted `legitimate`. **The Search/AUDIT.md numbers
("threat precision 100%, phishing 75% recall, scam 80% recall") do not match the
current code** (§6).

### 5.5 Methodological weakness (the most important finding in this section)

The split is by `caseId`, but the 105 cases are hand-written templates. Any
near-duplicate families (e.g. the many "social engineering" cases sharing the
same wording patterns) can straddle train and test, so "held-out" means
"different row", not "different scenario". With 21 test samples, one flip moves
accuracy by 4.8 points. The README's disclaimer is accurate; `docs/AUDIT.md`'s
framing of these numbers as a validated result is not.

---

## 6. Documentation review — outdated claims

| Doc | Claim | Reality (verified) |
|---|---|---|
| `docs/AUDIT.md` line 7, 383 | "`flutter test` → **365 tests pass**" | 415 registered tests; 411 pass, **3 fail**, 1 skipped. The claim was already false when written (never-ran suite) or has regressed since. |
| `docs/AUDIT.md` lines 6, 386 | "`flutter analyze` → No issues found" | Still true today. |
| `docs/AUDIT.md` lines 8-9, 387-388 | `flutter build web --release` + headless browser "0 console errors, 0 failed requests" | **Not re-run in this audit** (out of scope). Treat as unverified. |
| `docs/AUDIT.md` lines 55-67 | Held-out: 95.2% acc, **macro F1 95.9%**, **threat precision 100%**, phishing P100/R75, scam R80 | Actual: macro F1 **95.3%**, threat precision **92.9%**, phishing P100/**R100**, scam **R75%**. Per-class table is stale. |
| `docs/AUDIT.md` lines 157-177 | "honest numbers" with **threat precision 94.1%**, phishing P80/R100 | Superseded; current numbers above. Two contradictory tables now exist in one doc. |
| `docs/AUDIT.md` lines 340-342 (§4 item 5) | "`strictModeEnabled` and `onlineLookupEnabled` are stored but not yet wired into the analysis thresholds … the flag is currently inert." | **Outdated / self-contradictory**: line 41 of the same doc says the mode is wired, and §3.2 of this audit confirms it. `onlineLookupEnabled` is read at call time in `CompositeUrlReputationProvider` — but only on the `ThreatEngine.instance` path (§7.2). |
| `docs/AUDIT.md` line 349 | "Recommended next step: wire `strictModeEnabled` into `ThreatAnalyzer` thresholds" | Already done; stale recommendation. |
| `docs/AUDIT.md` line 324 | "dataset is **105** hand-written cases" | Correct. |
| `docs/IMPROVEMENT_PLAN.md` line 24, 36 | "`flutter test` → **153 passing**", "inflates the 153 tests passing figure" | Historical (pre-3.0) baseline; should be labelled as such so it is not read as current. |
| `docs/EXPANSION_PLAN.md` lines 79-80 | "Wire the currently-inert `strictModeEnabled`" | Outdated (already wired). |
| `README.md` lines 69-83 | Project structure lists only `core/models`, `core/services`, `features/analyzer`, `features/sms` | Incomplete: 8 feature packages, `core/theme`, `core/widgets`, Android `MainActivity.kt`. |
| `README.md` line 28 | "Optional online URL reputation infrastructure for future integration" | Partially accurate: Web Risk client exists; it is **not** reachable from `main.dart` today (§7.2). |
| Repo root | `test_results.txt` (69 KB), `hs_err_pid*.log` (3 files) committed | Stray run artifacts; no code impact but they mislead a reviewer about the current baseline. |

Note: `docs/TODO.md` already records E.4/E.5 as done, consistent with §3.2.

---

## 7. Verified architecture and findings

### 7.1 Two engine builders, and the live one is not the evaluated one

- `ThreatEngine._build()` (`threat_engine.dart` 129-158) trains on
  `MlTrainingDataset().build()` = **all 105 cases** and is what
  `ThreatEngine.instance` returns.
- `AppServices._build()` (`app_services.dart` 122-192) **also** trains on all 105
  cases and builds its own engine; `main.dart` uses `AppServices.instance`.
- `ModelInsightsScreen._evaluate()` (`model_insights_screen.dart` 37-59) and
  `test/model_evaluation_test.dart` split into 70/14/21 and train on the **70**
  training cases only.

Consequence: the classifier the user actually runs **has memorised the 21
cases** that Model Insights publishes as "held-out accuracy 95.2%". The reported
metric is the right procedure applied to the wrong model instance. This is the
same class of defect as AUDIT.md's B4, reintroduced at the composition root.

### 7.2 Online lookup is wired into the engine but absent from the app

- `AppServices._build()` builds `CompositeUrlReputationProvider` with
  `onlineProviders: const [UnavailableOnlineUrlReputationProvider()]`. Opting in
  changes a `ValueNotifier` that the provider reads, but the only "online"
  provider it can ever select is the *unavailable* stub. There is no
  `GoogleWebRiskUrlReputationProvider` in that list.
- `ThreatEngine._build()` uses the constructor default (`onlineEnabled` absent),
  and `CompositeUrlReputationProvider`'s own test confirms call-time gating, but
  no code path constructs the Web Risk provider in production.
- `GoogleWebRiskRestClient` / `GoogleWebRiskUrlReputationProvider` exist and are
  unit-tested, so the infrastructure is done; the composition is not.
- So the Settings subtitle implies a network call that cannot happen. The claim
  "no default-on network path" (`pubspec.yaml`) is correct; the claim that opting
  in performs an online lookup is not.

### 7.3 `phase1_regression_test.dart` — what ran vs. what was supplied

The file on disk is **not identical** to the version pasted in the task brief:

| Difference | Disk | Brief |
|---|---|---|
| Imports | includes `threat_rule_catalog.dart` and `threat_message.dart` | not present |
| Duplicate-rule test | iterates `ThreatRuleCatalog.rules` (id + per-rule `patterns`) | referenced a non-existent `ThreatRuleIds` |
| Settings test | uses `ThreatMessage(...)` instead of a duck-typed `_Message` | `_Message` shim |
| Watcher test name | "a stopped watcher does not poll" | "an unstarted watcher never polls" |
| Reliability | extra "a single unbroken token cannot stall analysis" | absent |
| Helpers at end | **none** (file ends after `main()`) | `_rules()` / `_catalogRules()` / `_catalogPatterns()` / `_Message` |

Result on disk: **41 tests, all pass** (46 s — dominated by the 200 KB hostile
inputs). Because the trailing helpers are missing, three tests in the brief could
**not** have been accepted by the analyzer; if they are part of Phase 1.1's
deliverable they must be authored correctly (the catalogue is
`ThreatRuleCatalog.rules`, each `ThreatRule` exposing `id` and `patterns`).

Also noted: the brief's `_Message` duck-type would have thrown at runtime
(`analyzeMessage` requires a `ThreatMessage`), which reinforces that the brief
file was never run. The on-disk version is the trustworthy one.

### 7.4 Other verified observations (no behaviour changed)

- `ThreatAnalyzer` bounds and caps input (`TextPreprocessor.bound` +
  `capTokenLength`) and reports `wasTruncated`; the ML extractor reads the same
  bounded text — the two engines cannot drift on length.
- `ThreatEngine` memoises by `source␁mode␁id` with FNV-1a id; mode is part of the
  key so a mode switch never serves a stale verdict.
- `_notAnalysed` is used for both "channel off" and "engine threw", and is
  explicitly not "safe".
- `ClipboardWatchService` reads only the **last** URL, raises an already-handled
  URL once, keeps a bounded 64-entry suppression list, checks consent + channel
  on every poll, and stops on lifecycle pause.
- `VerdictPolicy.assemble` is the only place `channelRiskBonus` is set; the
  channel bonus applies only when the message carries a URL and the mode is not
  Relaxed.
- `SenderAnalyzer.isCheckableShortCode` is the only "sender fact" the app
  verifies; full phone numbers and brand names are correctly not treated as
  facts.
- Tests that are really diagnostics print large reports (cross-validation 97.1%,
  hybrid 34/35, error analysis) — useful output, but their assertions are floors —
  see §5/§8.

---

## 8. Baseline commands — exactly what ran

| Command | Result |
|---|---|
| `flutter --version` | Flutter 3.47.4 / Dart 3.13.3 — exit 0 |
| `flutter analyze` | **No issues found!** (3.8 s) — exit 0 |
| `flutter test test/phase1_regression_test.dart` | **41/41 pass** (46 s) — exit 0 |
| `flutter test test/model_evaluation_test.dart` | **4/4 pass**; prints the table in §5.4 — exit 0 |
| `flutter test test/channel_and_protection_test.dart test/app_services_test.dart test/widget_test.dart test/logistic_regression_evaluation_test.dart test/ml_dataset_splitter_test.dart` (+ `model_evaluation_test.dart`) | **44/44 pass** (4 s) — exit 0 |
| `flutter test test/threat_evaluator_test.dart` | **1/1 pass**; rule engine 105 cases, 1 type error (`social_018`: expected socialEngineering, got phishing; level correct) — exit 0 |
| `flutter test` (whole suite, reporter `expanded`, logged) | **`+411 -3 ~1`**, ~1 min 10 s reported by the runner, exit 1 |

Not run in this audit (out of scope / not required): `flutter build web`,
headless-browser verification, `flutter test --coverage`, platform builds,
integration tests on a device.

### 8.1 Current failures (3)

All three are **metric-floor assertions that no longer match the model's current
output**, not crashes or compile errors. They share one root cause: the
classifier now makes **2** held-out errors instead of **1** (`phishing_001`
→ socialEngineering, `scam_001` → legitimate), and one rule-engine type error
(`social_018`).

| Test file | Assertion | Actual | Expected |
|---|---|---|---|
| `test/hybrid_threat_evaluation_test.dart` | `ruleCorrect >= 35` (held-out 35) | **34** | ≥ 35 |
| `test/hybrid_threat_diagnostic_test.dart` | `finalCorrectCount == 35` | **34** | 35 |
| `test/logistic_regression_error_analysis_test.dart` | `errorCount == 1` | **2** | 1 |

Notes:
- The failing numbers describe a **weaker** model than the docs claim. Any fix
  that simply relaxes the assertion (34, 2) would be "weakening tests", which
  this task forbids. The correct fix is to identify what changed (feature
  extractor / catalogue / split seed) and restore the previous behaviour *if* it
  was a regression — or make the floor honest and document the change. That
  decision belongs to the next task.
- `hybrid_threat_evaluation_test.dart:176` asks for `ruleCorrect >= 35` out of
  35 — a perfect-score assertion — which is also a fragile invariant.
- The brief's `phase1_regression_test.dart` counters: 41 tests pass on disk, but
  its "model that cannot score falls back to the rules" test only asserts the
  classifier is non-null; it does not exercise the fallback.

### 8.2 Skipped

One test is skipped in the full suite (`~1`). It is not skipped by this audit;
the skip marker is in the repository and it was not modified.

---

## 9. Likely issues — ranked

| # | Severity | Issue | Where | Evidence |
|---|---|---|---|---|
| 1 | **High** | Production classifier is trained on **all 105** cases while Model Insights reports metrics from a model trained on 70 — the live model has seen its own "test" fold. | `app_services.dart:149-157`, `threat_engine.dart:129-141` vs `model_insights_screen.dart:42-51` | code path of `main.dart` |
| 2 | **High** | "Held-out" split is by row over one hand-written template family; no scenario-level holdout, 21 test samples. | `ml_dataset_splitter.dart`, `evaluation_dataset.dart` | §5.5 |
| 3 | **High** | 3 failing tests; docs claim all green. | see §8.1 | full suite run |
| 4 | Medium | Online lookup can never go online: composition only lists `UnavailableOnlineUrlReputationProvider`. | `app_services.dart:164-168` | code |
| 5 | Medium | `falsePositiveRate` computes legitimate **FN rate** (misses), not legitimate **FP rate**; name and doc comment disagree. Its test cannot tell the difference. | `model_evaluation.dart:100-111`, `test/model_evaluation_test.dart` | code + run |
| 6 | Medium | `threatPrecision` pools all threat classes, so cross-class errors are invisible; docs quote it as if it were per-class truth. | `model_evaluation.dart:86-98` | code |
| 7 | Medium | `LocalStore.enabledChannels` turns an **empty** stored list back into "all channels"; all-off is not durable across restarts. `LocalSettingsSnapshot` disagrees (empty ⇒ empty). | `local_store.dart:176-194` | code |
| 8 | Medium | `docs/AUDIT.md` contains two contradictory metric tables and a stale "strict mode is inert" section; README structure is stale. | §6 | read |
| 9 | Low | `ProtectionMode.mlDowngradeThreshold` is public, mode-aware and unused. | `protection_mode.dart:65-70` | grep |
| 10 | Low | `threat_engine.dart` / `app_services.dart` duplicate engine construction; `CompositeUrlReputationProvider` import + defaults diverge. | both files | code |
| 11 | Low | Test hygiene: `hybrid_threat_evaluation_test.dart` asserts a perfect 35/35 rule score; three "diagnostic" tests are floor/print hybrids; `phase1_regression_test.dart` on disk lost its helper section. | `test/` | reads |
| 12 | Low | Repo root carries `test_results.txt` and `hs_err_pid*.log`; `.tmp_*` directories are untracked-looking but present. | repo root | `Get-ChildItem` |
| 13 | Info | `ThreatEngine.dispose()` disposes notifiers it does not own when built with external notifiers. | `threat_engine.dart:330-333` | code |

---

## 10. Recommended next task (ordered)

**Task 1.2 — Restore a trustworthy baseline (no behaviour redesign).**

1. **Decide the model-instance question first** (§9.1): either make
   `AppServices._build()` and `ThreatEngine._build()` train on the *same* split
   as `ModelInsightsScreen` (training fold only), or change Model Insights to
   evaluate the exact production model on the same fold. One of the two; then
   re-baseline every number.
2. **Then** investigate the 3 failing tests. The two held-out errors
   (`phishing_001`, `scam_001`) and the rule error (`social_018`) should be traced
   to whatever change moved them; restore behaviour if it was a regression,
   otherwise update the floors *and* record the new numbers in one place. Do not
   delete tests and do not loosen them without a written reason.
3. **Make the metric names honest** (`falsePositiveRate`, `threatPrecision`) and
   add a test that distinguishes FP from FN.
4. **Close the online-lookup gap** (§9.4): either register the Web Risk provider
   behind the existing consent flag or state in the UI that online lookup is
   unavailable. No default-on network path.
5. **Fix the all-channels-off persistence asymmetry** (§9.7) and add a
   round-trip test.
6. **Rewrite `docs/AUDIT.md`'s metric and "inert" sections** to a single set of
   numbers produced by a named command, and update README's project structure.

Explicitly out of scope for 1.1 (not started): any code change, dependency
bump, file move, `main.dart` edit, test deletion, version/signing change.
