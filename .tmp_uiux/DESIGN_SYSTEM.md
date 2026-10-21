# FixGo — Design System (shared tokens & component contracts)
**Document date:** 2026-10-16
**Scope:** customer-app (3000), worker-app (3001), admin-app (3002).
**Rule:** share primitives and semantics; do not force one identical layout on all roles
(customer = welcoming, worker = glanceable/dark-first, admin = dense).
This file is the token + decision record required by improvement-pack tasks 02 and 06.

---

## 1. Tokens (single source: each app's `tailwind.config.ts`)

### Color
| Token | Customer | Worker | Admin | Semantics |
|---|---|---|
| `primary` | `#FF6B00` / dark `#E65F00` | `#00B86B` / dark `#009A5A` | `#FF6B00` / `#E65F00` | brand + primary actions |
| `secondary` | `#1B1F3B` | `#FFC933` (amber) | `#1B1F3B` | customer hero / worker money accents |
| `surface` | white, `#F6F7F9` | `#0F1115`, `#1A1D23` bg, `#22262E` elevated | `#F6F7F9`, `#1A1D23` dark | page + card surfaces |
| `success` `#12B76A`, `warning` `#F79009`, `danger` `#F04438`, `info` `#2E90FA` | ✅ | ✅ | ✅ | status only — never as sole signal (pair with text/icon) |
| Money | n/a | `amber` (`#FFC933`) | n/a | earnings/balance only |

Status colors are **identical hex across all three apps** (verified). Worker keeps a
dark-first operational theme by design; semantics (spacing, type scale, status colors,
component states) are aligned with the brand.

### Typography
- Headings: **Poppins** (600/700); body: **Inter**. Si/ta: Noto Sans Sinhala / Noto Sans Tamil
  declared in customer + worker; **added to admin** in this pass (2026-10-16) for parity.
- Scale: page title 18–24 (font-heading), section 16–18 semibold, body 14–16,
  caption/label 11–12.

### Radius / shadow / spacing
- Radius: `rounded-xl` (12px) controls, `rounded-2xl` (16px) cards, `rounded-3xl` (24px) hero sheets.
- Shadows: `soft` / `card` / `lift` identical values in all apps; worker adds `glow` (focus/online) and `money`.
- Spacing: 4px base; page gutter 16px mobile (`max-w-lg` shell), 24px admin desktop.
- Safe area: `spacing.safe-bottom` = `env(safe-area-inset-bottom)`; bottom-nav padding via `.safe-bottom`.

### Motion (documented per guide 06)
- Durations: `--motion-fast: 120ms` (press/hover), `--motion-base: 180ms` (chips, small reveals),
  `--motion-slow: 240ms` (sheets, route transitions), `--ease-out: cubic-bezier(.2,.6,.4,1)`.
- Framer-motion press scale `0.97`; spring only for sheet entrance (damping 28, stiffness 300).
- **Reduced motion:** a global `prefers-reduced-motion: reduce` kill-switch now exists in
  **all three** apps' `globals.css` (customer + admin added this pass; worker already had it).
  It sets animation/transition durations to ~0 and disables smooth scrolling.
- Forbidden: continuous decorative movement (the worker jobs-home idle spinner was removed),
  motion that hides the offer countdown, or motion that delays an urgent action.

### Focus & touch
- Focus: `focus-visible:ring-2 ring-primary ring-offset-2` on all interactive primitives
  (admin uses `ring-primary/40` — its tokens, same pattern).
- Touch targets ≥ 44px (customer/worker buttons 52–56px; worker `xl` = 64px, glove-friendly).
- Inputs use 16px font on mobile to prevent iOS zoom.

## 2. Component contracts (per app `components/ui/`)
| Component | Customer | Worker | Admin | Contract |
|---|---|---|
| `Button` | variants: primary/secondary/ghost/danger/danger-outline/outline/success; sizes sm 40 / md 52 / lg 56; `loading` swaps icon + disables; `full` | same + `amber` (money CTA) + `xl` 64 | primary/secondary/ghost/danger/outline/success; h-9/10/11 (dense) | loading disables to prevent double submit; server idempotency remains the real protection |
| `Input`/`Textarea`/`Label` | 52px, ring focus | 52px dark elevated | h-10 dense | label always via `htmlFor`; helper/error text sits with the field |
| `Card` | white/dark `#1A1D23`, border + `shadow-card` | `surface` + `border` | white/slate | consistent across apps |
| `Badge` | info/success/warning/danger/neutral tones | + `amber`, `primary` | + neutral/primary | never color-only: rendered with status text (worker `StatusPill` maps every state to text) |
| `Skeleton` | `animate-pulse`, shape set by caller | same | same | used only for content actually loading; geometry matches final layout |
| `EmptyState` | icon + title + subtitle + action | same | same | empty states must explain why + next action |
| `Toggle` | 48×28 switch, `role="switch"`, `aria-checked`, **fixed this pass**: clean knob positioning + invisible 44px extended hit area (`before:` inset trick) | 56×32 dark variant | — | always `aria-label` when unlabeled |
| `SegmentedControl`/`Tabs` | pills | pills | underline tabs w/ counts | — |
| `Modal`/`BottomSheet` | `BottomSheet` (mobile-first, spring, drag-bar, 44px close w/ X icon + aria-label) | same | `Modal` centered, **44px close + X icon (fixed this pass, was 32px text glyph)** | focus stays in-dialog; Escape closes where implemented |
| `StatTile`/`StatCard` | — | worker tiles w/ tone icon | admin stat cards | value + label + optional hint |
| `RatingStars`, `Avatar` (initials fallback), `ProgressBar`, `CountdownRing` | shared contracts | | | icons decorative → `aria-hidden` / labelled parents |

## 3. Icons & imagery decisions (guide 06)
- **Icon library:** `lucide-react` only, stroke width 1.8–2.4 (active nav 2.4). No emoji as
  navigation/action icons. Landing emoji bullets are decorative content markers rendered with
  `aria-hidden` (the ⚡ slide marker) — acceptable, not core UI.
- **Category icons:** a single inline SVG map per app (`CategoryIcon` in customer + worker
  `Cards.tsx`). The apps are separate npm packages with no shared library, so the map is
  single-sourced *within each app*; a cross-app monorepo package would be needed to dedupe
  fully — recorded as future work, low risk (map is stable).
- **Images:** local `public/` assets only (manifest icons, maskable icons, favicon). **No
  external/hotlinked images used anywhere**, so no licensing/attribution work is outstanding.
  No AI-generated images. Avatars fall back to initials (no broken images).
- **Performance:** `next/image` where used (`WorkerCard`); lazy loading on below-fold imagery;
  skeletons reserve layout space to avoid CLS; no continuous repaint loops (only the
  `radar-ping`/`shimmer` keyframes remain, both compositor-friendly and disabled under
  reduced motion).

## 4. Component states matrix (required by guide 02)
| State | Requirement | Where verified |
|---|---|---|
| hover | color shift only, no layout change | all Buttons |
| pressed | scale 0.97 (framer `whileTap`) | customer/worker |
| focus-visible | 2px ring, offset 2 | all Buttons/Inputs |
| disabled | reduced opacity `bg-primary/40`, cursor-not-allowed (admin) | Buttons |
| loading | spinner replaces content; button disabled | Buttons; skeletons on lists |
| error | field-level text near field, value preserved | forms (rhf+zod) |
| empty | EmptyState with next action | customer home, worker jobs, admin tables |
| double-submit | UI disable + server `Idempotency-Key` | booking create |

## 5. Verification record (2026-10-16)
| Check | Command | Result |
|---|---|---|
| Typecheck | `npx tsc --noEmit` × 4 packages | all exit 0 |
| Builds | `npm run build` × customer, worker, admin | all exit 0 |
| Backend regression | `cd fixgo\backend; npm test` | **70 tests / 9 files pass** |
| Landing @1280 | headless Chromium | 0 console errors, 0 failed requests |
| Landing @360 | headless Chromium, screenshot | no horizontal overflow; slide dots labelled |
| Login @1280 | headless Chromium | 0 console errors |
