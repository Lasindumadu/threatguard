# ThreatGuard — Cybersecurity Expansion Plan

_Date: 2026-10-12 · Target: 3.0.0-dev_

## 1. The strategic problem with the app today

ThreatGuard currently answers **one** question: *"is this SMS a threat?"*

That is a feature, not a product. Every capability is SMS-specific: the message
source is `android_sms_message_source.dart`, the UI is an SMS inbox, and the
only inbound path is `READ_SMS`. A security team looking at this sees a
text-message classifier — useful, but scoped.

What makes an app look like a **platform** rather than a demo:

1. **Multiple intake channels**, because threats arrive in WhatsApp, Messenger,
   Instagram DMs, email, and on a web page clipboard — not just SMS.
2. **Protection beyond passive classification** — real-time interception,
   link quarantine, and a verdict delivered *before* the user taps.
3. **A broader security surface** — the app should answer questions the user
   actually has: *"is this link safe?", "is my password strong?", "is my number
   in a breach?", "is this app/URL impersonating my bank?", "what should I do
   right now?"*
4. **A unified, explainable console** where all of that lands in one risk view.

Section 5 lists the honest engineering constraints: several of these channels
cannot legally or technically be read by a third-party app, and the plan is
explicit about which ones are real integrations versus which are user-invoked
paste/share paths.

---

## 2. Workstream A — Multi-channel intake (the "connect everything" ask)

### A0. The honest constraint (must be stated up front)

| Channel | Can we read it automatically? | What we build instead |
|---|---|---|
| **SMS** | Yes, with `READ_SMS` (Play-restricted — see §5) or `SMS_RETRIEVAL`. | Android source (exists). |
| **WhatsApp** | **No.** Messages are E2E-encrypted in a private database; no third-party read API. We must not pretend otherwise. | Share-sheet intake: user shares a message to ThreatGuard. Plus *one-tap paste*. |
| **Messenger / Instagram DM** | **No** public message read API. | Shared-link / paste in through the share sheet. |
| **Email (Gmail/Outlook)** | Only via OAuth APIs with per-user consent. | Paste + share for now; OAuth scoped as a later item. |
| **Any app / web page** | Yes — via the **Android share sheet** and `ACTION_SEND` / `PROCESS_TEXT`. | **This is the universal integration** and the one we implement fully. |

**The design insight:** instead of five fake "integrations", build **one real
universal intake** — the Android share sheet — and make it excellent. From
WhatsApp/Messenger/Instagram/Gmail/Chrome, the user hits *Share → ThreatGuard*
and the message is analysed instantly. That is genuinely how Signal, Bitdefender
and Google's own tools operate, and it is defensible.

### A1. Universal share-sheet intake (`ACTION_SEND` + `PROCESS_TEXT`)
- Android manifest `<intent-filter>` for `text/plain` → opens ThreatGuard's
  **Quick Verdict** screen directly with the shared text.
- `PROCESS_TEXT` so it appears in the text-selection menu ("Check with
  ThreatGuard") inside any app.
- A `ShareIntentHandler` that routes cold-start intents to the right screen.

### A2. Quick Verdict screen
A focused screen that shows only the verdict, the score, the top three reasons,
and the recommended action — designed to be read in ~2 seconds, since it opens
straight from another app's share menu. One tap expands to full detail.

### A3. Channel-aware context
The shared text carries a `MessageSource` (`whatsapp`, `messenger`,
`instagram`, `email`, `web`, `manual`, `sms`). Channel changes the analysis:
- A URL in an **unsolicited WhatsApp/DM** is riskier than the same URL in an SMS
  from a known shortcode.
- Show "Checked from WhatsApp" so the provenance is explicit and honest.

### A4. Clipboard watcher (opt-in)
Detects a threat-looking URL in the clipboard and offers a non-intrusive
"Check this link?" chip. Off by default, with a clear privacy statement.

---

## 3. Workstream B — Real-time protection engine

### B1. `ProtectionMode` — strict/normal/relaxed
Wire the currently-inert `strictModeEnabled` into real thresholds
(`ThreatAnalyzer` score cut-offs and ML override thresholds). This was an open
item in `AUDIT.md §5`.

### B2. Link Interceptor / quarantine (`LinkShield`)
- **`LinkSafety`** service: given a URL, return `safe | suspicious | malicious |
  unknown` from structural analysis + local reputation + optional online lookup.
- **`QuarantineVault`**: high-risk URLs are rewritten to a `tg://shield/<id>`
  form. Tapping shows a full pre-flight warning: destination host, why it is
  flagged, and "continue anyway" behind a deliberate action.
- This is the single most product-visible feature — it stops the harm instead
  of describing it.

### B3. Adaptive thresholds from user feedback
The feedback loop from 2.0 is now *used*: `FeedbackCalibrator` adjusts per-user
thresholds from confirmed/false-alarm history, with hard safety floors so a user
cannot train the app into silence.

### B4. Risk escalation rules
Repeated high-risk messages from one sender within a window raises a
`SecurityAlert` ("a campaign is targeting you"), rather than N separate rows.

---

## 4. Workstream C — Broader cybersecurity surface

Each is a real, self-contained tool. This is what turns "message classifier"
into "security companion".

### C1. `LinkScannerScreen` — full URL forensics
Paste/tap any link for a deep report: host decomposition highlighted
(registrable domain vs subdomain), punycode/homoglyph display, shortener
expansion, IP host, non-standard port, embedded credentials,
`http` vs `https`, suspicious TLD, excessive subdomains, and — where the URL
*claims* to be an organisation — a mismatch verdict.

### C2. `PasswordAuditScreen` — passphrase health
- Entropy estimate, character-class breakdown, length, and patterns that kill
  strength (`Password123`, keyboard walks, dates, repeated chars).
- **Offline** common-password and pattern checks — never transmitted.
- **Breach check** by *k-anonymity range query* (send only the first 5 chars of
  the SHA-1; the full hash never leaves the device). This is the Have I Been
  Pwned model, and it is genuinely privacy-preserving.
- **Passphrase generator** using `Random.secure()` with an entropy read-out.
- Never persists the password; cleared on navigate-away.

### C3. `BreachExposureScreen` — am I exposed?
- Local breach catalogue bundled as data (`breach_catalog.dart`).
- Checks the user's email/phone against it **locally**; optional online range
  query only if the user opts in.
- Produces a prioritised "what to do" list (which accounts to rotate, in what
  order, and why).

### C4. `SecurityPostureScreen` — device hygiene self-check
A scored checklist that reads **real device state** where the platform allows:
- Screen lock / biometrics enabled (`FlutterKeyguard`-style platform call).
- OS patch age / developer-options enabled / unknown-sources installs.
- Permission audit: which apps can read SMS, contacts, location.
- Result is a 0–100 hygiene score with concrete remediation steps.

### C5. `ImpersonationEngine` — brand/domain impersonation
Generalises the existing `OrganizationRegistry` into a real detector:
- Levenshtein / keyboard-distance to an official domain (`paypaI.com`,
  `g00gle.com`, `amaz0n-secure.top`).
- Combines with `punycode`/`mixedScript` detection.
- Output: *"This domain is 1 character away from amazon.com — likely
  impersonation."* This is a high-value, easily-understood signal.

### C6. `ThreatFeedScreen` — learn + current campaigns
- Bundled, offline campaign advisory list (delivery scams, bank phishing,
  job-offer scams, romance scams) with real wording examples.
- Cross-links to Check, so "I got something like this" is one tap.
- Doubles as the **onboarding education** surface.

### C7. `SecurityTipsScreen` — personalised guidance
Rules-based recommendations driven by what the app actually observed (e.g. "you
receive many delivery-scam messages — here is how the fee scam works").

### C8. `VulnerabilitySurfaceScreen` — app permission posture
Summarise which permissions ThreatGuard holds, what each is for, and the
Play-Store justification text for `READ_SMS`. Directly addresses the policy risk
in `AUDIT.md §5` and reads as product maturity to a reviewer.

---

## 5. Workstream D — UX / "advanced modern view"

### D1. Navigation grows to a real console
`NavigationBar` (Dashboard · Inbox · Shield · Tools · Settings) with a
**Shield** tab for real-time protection state, and a **Tools** tab indexing
C1–C8.

### D2. `SecurityScoreHero`
A single 0–100 compound score on the dashboard — message risk + link exposure +
password hygiene + device posture — as an animated gauge, with the largest
contributor called out.

### D3. `RiskMeterField`, `VerdictBanner`, `TimelineChart`
Original visual components (no chart dependency): a custom-painted 7-day threat
sparkline, a full-bleed verdict banner, and an animated risk field.

### D4. Motion, haptics, polish
`Hero` transitions inbox→detail, staggered list entrance, `HapticFeedback` on
verdict reveal, shimmer skeletons instead of spinners.

### D5. Accessibility and trust signals
Semantics on every interactive widget, ≥48dp targets, contrast-checked risk
colours, and visible "on-device" badges wherever analysis happens.

---

## 6. Workstream E — Architecture & hardening

- `AppServices` — one composition root replacing ad-hoc singletons.
- `MessageSource` enum extended with the new channels.
- All new engines pure-Dart and unit-tested (no Flutter dependency), so they
  stay testable.
- Rate-limit / timeout on the online reputation client; offline-first always.
- Test coverage for every new engine, including adversarial inputs.

---

## 7. Honest constraints (what will *not* be claimed)

1. **We cannot read WhatsApp/Messenger/Instagram messages.** They are encrypted
   and there is no read API. Any app claiming otherwise is either asking for
   accessibility-abuse permissions or is lying. ThreatGuard uses the share sheet.
2. **`READ_SMS` remains Play-restricted.** Default-SMS-handler or approved use
   case is required; otherwise `SMS_RETRIEVAL`. Documented in C8.
3. **Breach checks are only as good as the catalogue.** Bundled data is a
   starting point, not live coverage; the online range query is opt-in.
4. **Device-posture checks are best-effort.** Android sandboxing limits what a
   non-system app can inspect; anything unavailable is reported as unknown
   rather than guessed.

---

## 8. Delivery order for this pass

1. **E** — `AppServices` composition root + extended `MessageSource`.
2. **B1** — protection modes wired into thresholds (closes an audit item).
3. **C5, C1** — impersonation engine + link scanner (pure Dart, testable).
4. **C2, C3** — password audit + breach exposure.
5. **B2** — link interceptor / quarantine.
6. **A** — share-sheet intake + Quick Verdict.
7. **C4, C6, C7, C8** — posture, feed, tips, permission surface.
8. **D** — navigation, security score hero, charts, motion.
9. Tests + `flutter analyze` + visual verification in a real browser.

## 9. Definition of done

- [ ] `flutter analyze` clean; `flutter test` green and expanded.
- [ ] Share sheet opens Quick Verdict from another app.
- [ ] Link scanner, password audit, breach check, impersonation detector,
      device posture, threat feed all reachable and functional.
- [ ] Compound security score on the dashboard.
- [ ] Protection mode actually changes detection thresholds.
- [ ] Every new engine has unit tests, including adversarial cases.
- [ ] Verified rendering in a browser (screenshots read back).
- [ ] `AUDIT.md` updated with what is real vs. what is a paste path.
