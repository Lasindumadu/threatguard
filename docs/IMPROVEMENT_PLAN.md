# ThreatGuard — Modernization & Product Plan

_Date: 2026-10-12 · Version target: 2.0.0_

## 1. Where the app stands today

ThreatGuard is a Flutter (Android) SMS threat-classification app. Current architecture is
already unusually well layered for a student project:

```
lib/
  core/
    models/     immutable domain models (ThreatAnalysis, MlFeatureVector, ...)
    services/   rules engine, ML, URL analysis, organization registry, SMS I/O
  features/
    sms/        inbox + detail screens
    analyzer/   manual paste-and-analyze screen
```

Strengths:
- Rule engine (`ThreatAnalyzer`) + logistic-regression classifier (`HybridThreatAnalyzer`).
- Structural URL analysis (IP hosts, punycode, shorteners, embedded credentials…).
- Organization registry for sender/domain consistency checking.
- 105-case evaluation dataset and a real test suite (`flutter test` → **153 passing**).

## 2. Bugs and defects found (verified by reading the code / running tests)

| # | Severity | Problem | Evidence | Fix |
|---|----------|---------|----------|-----|
| B1 | High | **`AnalyzerScreen` is dead code** — it is commented out in `main.dart`, so the entire manual-analysis feature is unreachable to a user. | `main.dart:3` | Build a real navigation shell and expose it. |
| B2 | High | **Classifier is retrained on every screen construction** (1000 epochs × ~5 classes × 105 samples) inside `initState`, and again inside `build()` indirectly via `_buildMessageCard` → `_analyzer.analyze`. Blocks the UI thread on cold start. | `sms_inbox_screen.dart:53-65` | Move training into a single shared, lazily-initialized service. |
| B3 | High | **`senderAnalyzer`/`organizationUrlAnalyzer` run on every list rebuild** — no caching or `memoization`, so scrolling re-analyzes every visible row. | `sms_inbox_screen.dart:441-449` | Cache a `MessageThreatReport` per message id. |
| B4 | High | **Broken dataset import.** `MlTrainingDataset` imports `EvaluationDataset` but calls `EvaluationDataset.cases.map(...)` — the file itself never compiles if that import is unused; more importantly the 105-case dataset is a *hand-written* fixture reused for training, so **train == test** (accuracy numbers are meaningless). | `ml_training_dataset.dart:12` | Split into train/dev/test and report honest metrics. |
| B5 | Medium | **Divergent URL extraction.** `ThreatAnalyzer._extractUrls` extracts bare domains (`example.com`) while `MlFeatureExtractor._extractUrls` only matches `http(s)://`/`www.` — the ML and rules see different URL sets for the same text. | `threat_analyzer.dart:760` vs `ml_feature_extractor.dart:256` | Extract once, in one shared helper. |
| B6 | Medium | **Rule engine matches substrings, not words.** `'pin'` in the credential rule matches "shipping", "spin", "opinion", "pint". `'otp'` matches "hotpot". Causes systematic false positives. | `threat_rule_catalog.dart:63` | Word-boundary matching + punctuation-aware tokenizer. |
| B7 | Medium | **`threat_diagnostic_test.dart` asserts nothing** — it only `print`s. It can never fail, yet it inflates the "153 tests passing" count. | `test/threat_diagnostic_test.dart:9-54` | Convert to real assertions. |
| B8 | Medium | **No `MLPrediction` alternatives / no explanation.** The UI shows a single label + confidence; there is no per-class probability, so no "why", no calibration, no trust. | `ml_prediction.dart` | Add full probability distribution. |
| B9 | Medium | **Android 14+ / Play Store risk.** `READ_SMS` without being the default SMS handler is a restricted permission; without a `READ_SMS` justification and a `role` declaration the app cannot ship. There is also no foreground notification, so the user has no signal that their inbox is being scanned. | `AndroidManifest.xml:3` | Document, add policy screens, and gate the feature. |
| B10 | Low | **`main.dart` has no `ThemeMode`, no dark theme, no `localizationsDelegates`** — `MaterialLocalizations.formatTimeOfDay` is used but only the default English delegate is implicit. | `main.dart:18-21` | Design system + theme + locale delegates. |
| B11 | Low | **Duplicated date formatter** copy-pasted verbatim in inbox and detail screen. | both screens | Extract to shared util. |
| B12 | Low | **`OrganizationRegistry` has only 3 Sri Lankan profiles** — useless for "attention from Google/Facebook" scale demos. | `organization_registry.dart` | Expand + make extensible/loadable. |
| B13 | Low | **No persistence** — analyses, mute list, user feedback (the single most valuable signal for an ML product) are all lost on restart. | — | Local storage layer + feedback → retraining loop. |
| B14 | Low | `RuleCatalog._applySignalIndicators` does an O(n²) linear scan to look up `scoreContribution` per signal. | `threat_analyzer.dart:101-106` | Fold into the signal. |

## 3. Vision — what makes this credible to a big company

Large security teams evaluate a project on five axes. The plan deliberately hits all five:

1. **Honest, reproducible evaluation.** A held-out test set, a confusion matrix, precision/recall/F1
   per class, and a published false-positive rate. *Most student projects fail here and it is the
   single biggest credibility lever.*
2. **Explainability.** Every verdict shows the exact evidence (matched span, weighted contribution)
   and a per-class probability distribution — not a black box number.
3. **Defence in depth.** Rules + ML + URL intelligence + sender/organization identity + link
   reputation, with an explicit, documented arbitration policy.
4. **A real user loop.** On-device feedback ("correct / missed") that personalizes thresholds and
   is exportable as a training set. Privacy-preserving by default.
5. **Product polish.** A modern design system, dark mode, accessibility, empty/error/loading states,
   a dashboard with trends, and an onboarding flow that explains the value before asking for
   a restricted permission.

## 4. Workstreams

### WS-A — Correctness & performance (bugs above)
Shared classifier singleton, per-message analysis cache, word-boundary matcher, unified URL
extraction, real assertions in diagnostics.

### WS-B — Explainable, honest ML
- `MlPrediction` gains `probabilities` (map class → probability) and `margin`.
- `LogisticRegressionClassifier` exposes `predictProbabilities`.
- New `ModelEvaluation` service: train/dev/test split, confusion matrix, per-class
  precision/recall/F1, macro-F1, accuracy, and a **false-positive rate on the hard-negative set**.
- Report surfaced in a new **Model Insights** screen so reviewers can see the numbers.

### WS-C — New detection engines
- **`TemplateFingerprint`**: near-duplicate campaign detection (content hashing + shingles) →
  "this is the 47th copy of a campaign we've seen" is a genuinely strong, product-visible signal.
- **`RiskTimeline` / trend tracking**: threat volume by day and category.
- **`UrlIntelligenceService`** wiring for on-device heuristics + optional online reputation,
  with an offline-first cache.
- **Sender reputation**: rolling per-sender history (block rate, verdict mix).

### WS-D — Persistence & feedback loop
`SharedPreferences`-backed `LocalStore` for: user verdict overrides, muted senders, analysis
history, and app settings. Export feedback as CSV/JSON (a shareable artifact).

### WS-E — UI/UX overhaul
- `AppTheme` design system (Material 3, seeded colour, dark mode, elevation/typography scale,
  risk colour tokens).
- `HomeShell` with `NavigationBar`: **Dashboard · Inbox · Analyze · Settings** — fixes B1.
- Redesigned inbox: search, filters (All / High risk / Suspicious / Safe), sort, risk-colored
  leading indicator, swipe to mute.
- Redesigned detail: hero risk gauge, confidence breakdown bar per class, evidence list with
  highlighted matched text, tech-vs-human-readable toggle.
- New **Dashboard**: risk summary, category distribution, recent high-risk items, trend.
- New **Settings**: thresholds, online lookup toggle, feedback export, privacy statement.

### WS-F — Security & privacy posture
Privacy-first README section, `READ_SMS` justification, data-never-leaves-device statement,
"no analytics" guarantee, offline-first behaviour.

## 5. Delivery order (this pass)

1. WS-A correctness fixes (B1, B2, B3, B5, B6, B14) + keep all tests green.
2. WS-B explainable ML + evaluation harness (B8).
3. WS-D persistence + WS-C template fingerprinting.
4. WS-E design system, `HomeShell`, Dashboard, redesigned Inbox/Analyze/Detail/Settings.
5. WS-F docs + README.

## 6. Definition of done for this pass

- [ ] `flutter analyze` reports no errors.
- [ ] `flutter test` green, with diagnostics converted to real assertions.
- [ ] App opens on a Dashboard, not an empty inbox.
- [ ] Manual analyzer reachable from navigation.
- [ ] Classifier trained exactly once per process.
- [ ] Every verdict shows per-class probabilities + matched evidence.
- [ ] Model Insights screen shows accuracy / macro-F1 / confusion matrix.
- [ ] Dark mode + light mode both render.
- [ ] Findings written up in `docs/AUDIT.md`.
