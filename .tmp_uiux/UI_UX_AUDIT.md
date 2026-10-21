# FixGo — UI/UX Audit (improvement pack 01–11)
**Document date:** 2026-10-16
**Source:** read-only recon of `fixgo/customer-app`, `fixgo/worker-app`, `fixgo/admin-app`
against `FixGo_AI_Agent_Improvement_Pack` tasks 01–07. This is the working map for the
UI/UX quality pass; it is based on the actual files inspected, not on older audits.
**Baseline verified 2026-10-16:** `npx tsc --noEmit` exits 0 in backend, customer, worker, admin.
(Backend suite at last recorded run: 70 tests / 9 files — re-run before release claims.)

---

## 1. Route / screen inventory (verified)

### customer-app (Next 15, port 3000, max-w-lg mobile shell)
| Route | File | Notes |
|---|---|---|
| `/` landing | `src/app/page.tsx` | value prop, category cards, worker CTA. Uses 3 decorative dots as "slides" — carousel never implemented (P1-2) |
| `/app` home | `src/app/(app)/page.tsx` | search, promo, categories, popular, book-again, top-rated; skeletons match cards |
| `/login` | `src/app/login/page.tsx` | phone + OTP (OTPInput component), resend countdown |
| `/app/book` | `src/app/(app)/book/page.tsx` | estimate breakdown present |
| `/app/bookings`, `/app/bookings/[id]` | | status timeline present |
| `/app/services/[id]`, `/app/categories/[slug]`, `/app/search` | | discovery |
| `/app/chat`, `/app/chat/[bookingId]`, `/app/wallet`, `/app/account`, `/app/profile`, `/app/addresses`, `/app/favorites`, `/app/help`, `/app/notifications`, `/app/workers`, `/app/workers/[id]`, `/onboarding`, `/offline` | | |

### worker-app (port 3001, dark-first)
| Route | File | Notes |
|---|---|---|
| `/app` jobs home | `src/app/app/page.tsx` | online toggle, warnings, stats, active job, map, scheduled |
| `/app/job/[id]` | | active job (31.6kb — largest screen) |
| `/app/schedule`, `/app/open-jobs`, `/app/earnings`, `/app/wallet`, `/app/performance`, `/app/heatmap` | | |
| `/app/account/*` (profile, bank, documents, services), `/app/help`, `/app/notifications` | | |
| `/login`, `/onboarding`, `/onboarding/kyc` (7-step wizard), `/verification`, `/offline` | | |

### admin-app (port 3002, desktop sidebar + mobile drawer)
| Route | Notes |
|---|---|
| `/` dashboard | 8 stat cards + revenue + recent bookings table |
| `/bookings`, `/workers` (KYC), `/users`, `/catalog`, `/payouts`, `/coupons`, `/disputes`, `/support`, `/reports`, `/broadcast`, `/audit`, `/settings`, `/live-map`, `/login` | |

## 2. Current design tokens (verified from `tailwind.config.ts` + `globals.css`)

| Token | customer | worker | admin |
|---|---|---|---|
| Primary | `#FF6B00` orange | `#00B86B` green | `#FF6B00` orange |
| Surfaces | white / `#F6F7F9` / dark `#1A1D23` | `#0F1115` / `#1A1D23` / `#22262E` | `#F6F7F9` / dark `#1A1D23` |
| Status colors | success/warning/danger/info identical hex in all three ✅ | same | same |
| Fonts | Inter + Poppins (+ si/ta) | same | Inter + Poppins (no si/ta declared) |
| Radius | 2xl=1rem, 3xl=1.5rem | same | same |
| Shadows | soft/card/lift | same + glow/money | same |
| Safe area | `safe-bottom` spacing ✅ | ✅ | not needed (no bottom nav) |

**Gaps / inconsistencies found:**
1. **Hard-coded hex literals** instead of tokens across pages: `dark:bg-[#1A1D23]`, `dark:text-[#F2F4F7]`, `bg-[#0F1115]`, `#3A3F47` etc. appear in nearly every customer/worker page. Token classes exist (`bg-surface`, `text-muted`) but pages mix both (P2, large surface).
2. **Admin dark mode** uses raw `slate-*`/`#141821`/`#1A1D23` values not present in its tailwind config — inconsistent with the other two apps (P2).
3. **Motion durations** are mostly framer-motion springs (0.97 press scale); no shared motion token. Worker `globals.css` has a global `prefers-reduced-motion` kill-switch; customer and admin do not (P1-1).
4. **Focus rings** inconsistent: customer/worker `focus-visible:ring-2 ring-primary`, admin `ring-primary/40`; inputs use `focus:ring-2` not `focus-visible` (P2).
5. **Icon set:** lucide-react everywhere ✅ plus a duplicated 12-entry inline category SVG map — identical copy in customer `Cards.tsx` AND worker `Cards.tsx` (drift risk, P2-1).
6. **Toggle knob (customer primitives):** inline `style` sets `left: checked ? 24 : 4` overriding the Tailwind `left-6/left-1` classes, and `top:50%`+`translateY(-50%)` fights the `top-1` class. Works but fragile; also `min-h-[44px] min-w-[48px]` on a 28px switch creates an oversized invisible hit area that can overlap neighbours (P2-3).
7. **Admin Modal close button** uses a text glyph `✕` with no icon library and `w-8 h-8` (32px < 44px touch target) (P2-4).
8. **Admin font stack** doesn't declare si/ta fonts while the other apps do (P2).

## 3. Findings by priority

### P0 — functional / security (verified elsewhere, unchanged by UI work)
- None new from this UI recon. Backend P0s were closed in the previous pass (IDOR, PIN lock,
  uploads, webhook dedup, payout atomicity — see `RELEASE_EVIDENCE.md`). **UI must not
  reintroduce any of these**: no optimistic payment/booking success, no display of `startPin`
  to unauthorized viewers, no KYC URLs in public markup.

### P1 — major usability
| # | Finding | Where | Fix |
|---|---|---|---|
| P1-1 | No `prefers-reduced-motion` support in customer or admin | customer/admin `globals.css` | add the same global reduced-motion block the worker app already has |
| P1-2 | Landing "slides" indicator shows 3 dots but nothing rotates — reads as broken | customer `page.tsx` | replace with a real simple auto-rotating hero or a single static slide |
| P1-3 | Worker jobs-home empty state uses a continuously spinning refresh icon while online — constant decorative movement | worker `app/page.tsx` | stop spinning after first load; show a static "listening for offers" state |
| P1-4 | Admin mobile: no in-content page titles on deep pages; relies on back gesture | admin pages | add consistent page header w/ title inside content |
| P1-5 | Offer expiry countdown must never be motion-hidden (guide 04) — verified OK, keep as invariant | worker OfferListener | keep |

### P2 — polish (representative, not exhaustive)
| # | Finding | Where |
|---|---|---|
| P2-1 | Duplicated category-icon map in two apps | customer+worker `Cards.tsx` |
| P2-2 | Hard-coded dark hexes everywhere instead of tokens | all pages |
| P2-3 | Customer Toggle knob inline-style fragility | customer `primitives.tsx` |
| P2-4 | Admin Modal close <44px target, text glyph | admin `ui.tsx` |
| P2-5 | Admin lacks `apple-touch-icon` link tag in layout | admin `layout.tsx` |
| P2-6 | Customer landing emoji bullets used as content markers without `aria-hidden` | customer `page.tsx` |
| P2-7 | Admin dashboard table empty state is a bare `Td` row, not the EmptyState component | admin `(console)/page.tsx` |

## 4. Existing libraries (no new deps needed)
next 15, react 19, tailwind 3.4, lucide-react 0.469, framer-motion, tanstack query, zustand,
sonner, react-hook-form+zod, recharts, leaflet/react-leaflet, next-themes, socket.io-client,
date-fns. **Icons: lucide-react only. Images: local `public/` assets only — no external
image usage found, so no licensing work required.**

## 5. Proposed task order (maps to improvement pack)
1. **Task 02** — add reduced-motion + focus tokens + motion durations to all three apps' CSS/config; document in `DESIGN_SYSTEM.md`.
2. **Task 03** — customer: fix landing slides (P1-2), aria-hidden emoji, apply token classes where touched; re-verify booking journey.
3. **Task 04** — worker: stop idle spinner (P1-3), keep offer/SOS invariants; verify active-job hierarchy.
4. **Task 05** — admin: page headers (P1-4), Modal touch target + icon close (P2-4), dashboard empty state (P2-7), si/ta font stacks.
5. **Task 06** — single-source the category icon map inside each app that uses it; document motion/icon/asset decisions in `DESIGN_SYSTEM.md`.
6. **Task 07** — responsive/keyboard pass at 360/390/768/1366 in browser; record results.
7. **Task 08** — typecheck + build all apps, backend `npm test`, update `RELEASE_EVIDENCE.md` ledger rows.
8. **Task 09** — remains HUMAN/provider-owned (B1–B10, device QA); do not touch.

## Safety constraints honored
- No package-manager/lockfile changes (npm only), no new dependencies.
- No auth guards, API payloads, price logic, or state machines touched by UI work.
- Demo credentials stay only in local docs, never in production code.
- No screenshots/fabricated evidence; real commands only.
