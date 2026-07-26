# RaatikDesk UI Redesign — Windows Flutter Client

**Date:** 2026-07-26  
**Status:** Approved  
**Release version:** `2026.08.01` (Cargo/pubspec semver: `2026.7.1` — no leading zeros)  
**Branch:** `raatik/ui-2026.08.01`  
**Baseline:** RaatikDesk white-label on RustDesk 1.4.9 (`raatik/1.4.9`)  
**Related:** [2026-07-25-raatikdesk-rebrand-design.md](./2026-07-25-raatikdesk-rebrand-design.md)

## 1. Goal

Redesign the RaatikDesk Windows desktop UI so AutoFi (اتوفای) customers and RAATIK support can use it in **RTL Farsi** with **meaningful** labels, Raatik visual identity, and no remaining customer-visible RustDesk chrome — without rewriting the remote-desktop engine.

This app is RAATIK’s remote-support client for AutoFi accounting customers. Customers are the primary audience; support staff are secondary.

## 2. Confirmed decisions

| Topic | Choice |
|---|---|
| Audience | Customers first, support second |
| Visual brand | Raatik corporate + calm support-tool feel (share Raatik logo; not an AutoFi UI clone) |
| Redesign depth | Full redesign of home, settings shell, and remote toolbar (Approach 1) |
| Home layout | **B1** — RTL two-column; receive panel dominant; connect panel secondary |
| Theme | Light default + dark available in settings |
| API / cloud UI | Hide until API exists; do **not** redesign those screens |
| Admin | Always elevate — `requireAdministrator` (UAC on cold start) |
| Font | IRANSansXFaNum only (already present under `flutter/assets/`) |
| RTL | Full app RTL when locale is Farsi; LTR when English |
| Implementation approach | **1 — Theme shell + page rewrites** (keep FFI/models) |
| Remote toolbar | **T1 — persistent top bar** |
| Local UI check | Flutter **web preview harness** (mocked); real `.exe` via GitHub Actions |
| Build | CI-only for shipping artifacts (unchanged from rebrand design) |

## 3. Out of scope

- Mobile / Android / iOS / macOS / Linux shipping UIs
- Redesigning API login, cloud address book, or Pro account flows (hidden only)
- Changing rendezvous/relay protocol or server topology
- Auto-migrating device IDs from old RustDesk installs
- Pixel-perfect AutoFi product UI matching
- Local full Windows native toolchain builds (optional Flutter SDK for preview only)

## 4. Architecture

### 4.1 Approach 1 — Theme shell + page rewrites

Keep existing Flutter models and `flutter_rust_bridge` FFI. Replace presentation:

| Layer | Action |
|---|---|
| Theme | Replace stock `MyTheme` blues with Raatik tokens (light + dark) |
| Typography | Register IRANSansXFaNum in `pubspec.yaml`; set as app `fontFamily` |
| Direction | Root `Directionality` / locale-driven RTL for `fa` |
| Home | Rewrite `desktop_home_page` (+ connection panel) to B1 layout |
| Settings | Rewrite settings shell IA and Farsi copy; keep option keys/bindings |
| Remote toolbar | Replace floating/stock chrome with T1 top bar; same underlying actions |
| API surfaces | Gate with `kRaatikApiEnabled = false` (single flag) |
| Preview | New entrypoint `lib/preview_main.dart` with fake models for Chrome |

Upstream merge strategy remains: mechanical theme/RTL/font + focused page diffs; avoid forking session/IO logic.

### 4.2 Feature flag

```dart
const bool kRaatikApiEnabled = false;
```

When false: hide login entry points, cloud address book, and any settings that only make sense with an API. When RAATIK adds an API later, flip the flag and optionally design those screens in a new spec.

## 5. Visual design system

### 5.1 Colors

Derived from the Raatik mark (cyan/blue). Soft UI Evolution style: calm surfaces, clear contrast, no purple SaaS defaults.

| Token | Light | Dark | Role |
|---|---|---|---|
| Primary | `#0284C7` | `#38BDF8` | Nav active, links, focus |
| Accent / CTA | `#0891B2` | `#22D3EE` | Primary buttons |
| Success | `#059669` | `#34D399` | Ready / connected |
| Danger | `#DC2626` | `#F87171` | End session / errors |
| Surface | `#F8FAFC` | `#0F172A` | App background |
| Card | `#FFFFFF` | `#1E293B` | Panels |
| Text | `#0F172A` | `#F1F5F9` | Body |
| Muted | `#475569` | `#94A3B8` | Hints (≥4.5:1 on surface) |
| Border | `#E2E8F0` | `#334155` | Dividers |

Window title bar: flat Primary (no stock RustDesk loud gradient).

### 5.2 Typography

- **Font:** IRANSansXFaNum (Regular / Medium / Bold)
- Body ≥ 16px on desktop; line-height ~1.6
- IDs and one-time passwords use FaNum tabular digits
- No emoji as icons — SVG / Material-consistent icon set only

### 5.3 Motion & a11y

- Micro-interactions 150–300ms ease-out
- Respect `prefers-reduced-motion`
- Visible focus rings; touch/click targets ≥ 44px where practical
- Loading: spinner/skeleton only

## 6. Home (B1)

RTL two-column layout:

**Dominant panel (receive — customer path)**

- Heading: e.g. «آماده برای پشتیبانی اتوفای»
- Helper: «شناسه این سیستم را برای پشتیبان بخوانید یا کپی کنید»
- «شناسه من» + copy
- «رمز یک‌بارمصرف» + copy / refresh (existing behavior)
- Primary CTA: «کپی شناسه و رمز»

**Secondary panel (connect — support path)**

- Heading: «اتصال به سیستم دیگر»
- Helper: «برای تیم پشتیبانی»
- Destination ID field + «اتصال»
- Recent peers list may sit under this panel (local only; no cloud AB)

**Chrome**

- Title: RaatikDesk + Raatik logo asset
- Settings entry in title/menu area
- No `setup_server_tip` banner

## 7. Settings IA

RTL sidebar groups:

| Group | Items | Notes |
|---|---|---|
| عمومی | عمومی و ظاهر | Language (fa/en), theme light/dark, start with Windows |
| | امنیت و دسترسی | Permanent password, approval, permissions |
| برای پشتیبان | نمایش و کیفیت تصویر | Quality vs speed explained in Farsi |
| | شبکه و سرور راتیک | Prefilled `remote.raatik.ir`; remains editable |
| | پیشرفته | Rare options |
| درباره | درباره RaatikDesk | Version; links to `raatik.com` |

Every non-obvious setting includes a short Farsi «این یعنی چه؟» subtitle (meaningful copy, not English calques).

**Removed UI copy:** `setup_server_tip` — «برای اتصال سریعتر، سرور اتصال شخصی خود را راه اندازی کنید» (and equivalent display sites).

**Hidden (API flag):** account login, cloud address book, related menu items.

## 8. Remote toolbar (T1)

Persistent **top bar** over the session:

- Brand + optional peer label
- Primary actions visible (e.g. فایل، گفتگو، کنترل صفحه)
- Overflow «بیشتر» for less-used tools
- Strong «پایان جلسه» (danger styling)

Meaningful Farsi labels (examples, finalize in implementation):

| Concept | Label direction |
|---|---|
| Display / control | کنترل صفحه |
| File transfer | ارسال/دریافت فایل |
| Audio | صدای مشتری |
| Privacy mode | حریم خصوصی صفحه |
| OS / CAD | کنترل ویندوز |

Underlying action handlers stay the same as today’s toolbar; only chrome and labels change.

## 9. Platform & brand leftovers

### 9.1 In-window logo

Taskbar icon may already be Raatik; title-bar / in-app logo still uses stock assets. Replace at least:

- `flutter/assets/logo.png` (see `_kDefaultLogoAsset` in `common.dart`)
- Any `_AppIcon` / tray assets still pointing at RustDesk art
- Confirm `windows/runner/resources/app_icon.ico` consistency with title bar

### 9.2 Force run as administrator

Set Windows manifest `requestedExecutionLevel` to `requireAdministrator` for the main client executable (and portable wrapper if that is the shipped artifact). Accepted UX: UAC on every cold start. Document for support scripts and customer install notes.

### 9.3 Remaining RustDesk UI strings

- Empty or rewrite customer-visible tips that still say RustDesk or push self-hosting (`setup_server_tip`, install/UAC tips that name RustDesk awkwardly in `fa.rs`, About strings, etc.)
- Rely on existing `APP_NAME` substitution where it already works; fix exemptions and hardcoded Flutter strings that bypass it
- Preserve AGPL copyright headers and `LICENCE` (trademark removal ≠ copyright removal)

## 10. Localization policy

- Default language: Farsi; English remains available
- Rewrite customer-facing `fa.rs` values for clarity (action + consequence), not literal translation
- Do not translate technical tokens: UAC, 2FA, TCP, UDP, TLS, etc. (per `AGENTS.md`)
- Brand token in UI: always **RaatikDesk** (Latin) in chrome and About; Farsi sentences may say «برنامه» where natural — do not invent a separate Persian product spelling in v1

## 11. Local UI preview harness

**Problem:** Full Windows client build needs Rust, vcpkg, VS — too heavy for day-to-day UI iteration on this machine.

**Solution:** `flutter/lib/preview_main.dart` (and minimal fake model stubs) that renders:

- Home B1
- Settings shell
- Toolbar T1 chrome
- Light/dark + RTL + IRANSansXFaNum + Raatik logo

Run (Flutter SDK only):

```bash
cd flutter
flutter run -d chrome -t lib/preview_main.dart
```

**Not in scope for preview:** real connections, elevation, FFI. Shipping behavior verified via GitHub Actions artifacts.

Stock `flutter run -d chrome` on the full app is **not** the plan — desktop plugins/FFI will not work without a dedicated harness.

## 12. Error handling & edge cases

- Elevation denied (user cancels UAC): app does not start; Windows shows standard failure — document in install notes
- Missing font files: CI/build must fail if IRANSansXFaNum assets are not registered
- English mode: LTR layout; keep meaningful (not broken) English strings
- API flag true in future: hidden entries reappear without requiring a home/settings redesign

## 13. Testing & acceptance

1. **Preview (local):** RTL, font, B1 home, settings groups, T1 bar, light/dark, no API entries, no server-tip banner, Raatik logo top-left  
2. **CI no-leak gate:** extend/keep checks so customer-visible “RustDesk” does not regress in fa/en UI paths  
3. **Actions artifact:** install/run elevated; taskbar + title-bar icons Raatik; connect path smoke as today  
4. **Support dry-run:** one AutoFi-style customer receive flow + one support connect flow with new labels

## 14. Implementation phases (for later planning)

1. Tokens + font + RTL + logo assets + admin manifest  
2. API gate + remove `setup_server_tip` + brand string sweep  
3. Home B1 rewrite  
4. Settings IA + Farsi subtitles  
5. Remote toolbar T1  
6. Preview harness  
7. CI gates + Actions verification  

Detailed task breakdown belongs in the implementation plan after this spec is approved.

## 15. Open points resolved in brainstorm

| Question | Resolution |
|---|---|
| Primary user | Customers first (D) |
| Look vs AutoFi | Raatik corporate + fresh support-tool (B+C) |
| Depth | Full redesign of listed surfaces (C) |
| Home | Split B1 columns |
| Theme | Both; light default |
| Login/API | Hide; no redesign |
| Admin | Always elevate (A) |
| Approach | Theme shell + page rewrites (1) |
| Toolbar | T1 top bar |

No intentional TBDs remain for v1 scope above.
