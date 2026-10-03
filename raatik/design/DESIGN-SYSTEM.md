# RaatikDesk Design System

Status: v1, 2026-10-03. Source of structure: a reference Persian RTL RustDesk client
(six screenshots: compact home, medium home, wide home, session toolbar + display
menu, session window header, password dialog). Colours are **not** taken from the
reference. RaatikDesk keeps its own palette (`RaatikTokens.primary` and friends).

The screenshots are in `reference/` next to this file (`home-compact.png`,
`home-medium.png`, `home-wide.png`, `session-display-menu.png`,
`session-header.png`, `password-dialog.png`). Look at them for structure and
proportion only.

This document is the single source of truth for *how RaatikDesk looks and behaves*.
`SCREENS.md` turns it into per-screen blueprints. The agent skill
`.claude/skills/raatik-desk-design/SKILL.md` tells an AI agent how to apply both.

---

## 0. Design principles (read first)

1. **Right-to-left is the primary direction, not a mirror pass.** Every layout is
   designed in RTL. Leading = right, trailing = left. Latin text, IDs and paths
   are LTR islands inside RTL text.
2. **One job per surface.** The home window has exactly three zones: navigation
   (side), a hero zone (connect / your desktop), and the peer list. Nothing else
   competes for attention.
3. **The ID is the hero.** The remote-ID field and the primary "اتصال" button are
   the largest interactive elements on screen at every width.
4. **Progressive disclosure by width.** Labels appear as width grows. Nothing is
   removed from the product at narrow widths; it collapses to icons or moves to a
   menu.
5. **Flat surfaces, strong containers.** No drop shadows for separation. Hierarchy
   comes from nested rounded containers, 1px borders and surface tint.
6. **Numbers are machine data.** IDs, passwords, versions and IPs render in Latin
   digits, grouped, tabular, LTR-isolated and copyable. Persian digits are for
   prose only.
7. **Every control is 44px tall or bigger.** Toolbar icon buttons inside a
   grouped cluster may be 36px because the cluster itself is the target.
8. **State is visible without reading.** Service status, peer online state and
   session state are coloured dots or filled/outlined switches, always in the
   same place.

---

## 1. Foundations

### 1.1 Direction and bidi

| Rule | How |
|---|---|
| App `Directionality` is RTL whenever the UI language is `fa`. | Already the case; never wrap a screen in a hard `TextDirection.ltr`. |
| Use directional APIs everywhere. | `EdgeInsetsDirectional`, `AlignmentDirectional`, `BorderRadiusDirectional`, `PositionedDirectional`, `start`/`end`, `Row` with default direction. Never `left`/`right` for layout. |
| LTR islands. | Wrap IDs, hostnames, `user@host`, URLs, file paths, version strings and key names with `ltrIsolate()` from `raatik/bidi/ltr_isolate.dart`, or `ltrTextDirection()` for widgets. |
| Mirrored icons. | Back/forward arrows, the connect arrow, submenu chevrons, "send", list indent, undo/redo. In RTL "forward" points **left** (←). |
| Never mirrored. | Checkmarks, refresh, clocks, media controls, monitor/keyboard glyphs, the brand logo, copy, eye. |
| Scrollbars. | Default placement (left edge in RTL). Do not force them right. |
| Text alignment. | `TextAlign.start` for Persian; identifiers centred inside their own field; never hard `TextAlign.right`. |

### 1.2 Spacing scale

Base unit 4. Use only these values.

| Token | px | Use |
|---|---|---|
| `space1` | 4 | icon-to-dot, chip inner padding (vertical) |
| `space2` | 8 | inside grouped clusters, between icon and label in a tab |
| `space3` | 12 | gap between cards, grid gap, icon-label gap in buttons |
| `space4` | 16 | window gutter, card padding (compact), between hero rows |
| `space5` | 20 | card padding (medium / wide) |
| `space6` | 24 | dialog padding, section gap in settings |
| `space8` | 32 | hero vertical padding at wide |

Existing `RaatikTokens.spaceXs..spaceXl` map to `space1..space5`.

### 1.3 Radius scale

| Token | px | Use |
|---|---|---|
| `radiusXs` | 8 | toolbar icon buttons, chips, checkbox, segments inside a cluster |
| `radiusSm` | 12 | buttons, text fields, nav items, menu items, session tab |
| `radiusLg` | 16 | cards, peer tiles, dialogs, the floating toolbar cluster |
| `radiusXl` | 20 | outer hero container that wraps the two hero cards |
| `radiusPill` | 999 | search field, status badges, segmented tab active pill, power button |

Nested containers step down one level: outer 20 → inner cards 16 → controls 12 → chips 8.

### 1.4 Sizes

| Token | px | Use |
|---|---|---|
| `control` | 44 | min height of every button, field, nav item, tab |
| `heroInput` | 52 | remote-ID field and the primary CTA next to it |
| `toolbarBtn` | 36 | icon button inside the session toolbar cluster |
| `toolbarBar` | 48 | session toolbar / window header height |
| `rail` | 64 | icon nav rail width (compact and medium) |
| `sidebar` | 232 | labelled sidebar width (wide); same as `RaatikSettingsShell.sidebarWidth` |
| `heroMax` | 640 | max width of the centred connect card at wide |
| `dialogMax` | 560 | `RaatikDialogStyle.maxWidth`; confirmation dialogs use 360 |
| `tileMaxExtent` | 220 | peer grid uses `SliverGridDelegateWithMaxCrossAxisExtent(220)`; tiles never narrower than 180 |
| `tileHeader` | 96 | coloured top area of a peer tile |
| `tileFooter` | 40 | bottom strip of a peer tile |
| `iconSm / iconMd / iconLg / glyph` | 16 / 20 / 24 / 48 | inline, buttons, rail, platform glyph |
| `dot` | 8 | status dot (10 inside peer tile footer) |

### 1.5 Breakpoints (window width)

| Class | Width | What changes |
|---|---|---|
| `compact` | < 640 | Icon rail. Hero cards stacked. Utility cluster collapses into one overflow menu. Tabs show icon + label and scroll horizontally. Peer grid 2 columns. |
| `medium` | 640 – 1199 | Icon rail. Hero cards side by side (connect leading, your-desktop trailing). Utility cluster icon-only. Peer grid auto-fit. |
| `wide` | ≥ 1200 | Labelled sidebar replaces the rail and absorbs the "your desktop" panel. Connect card centred at `heroMax` with subtitle and illustration. Utility cluster icon + label. |

`raatikWindowClassFor` in `raatik/layout/breakpoints.dart` must move to these
values (compact currently ends at 900).

### 1.6 Typography

Font: `IRANSansXFaNum` (already bundled, weights 100–900). Persian needs more
leading than Latin; the scale below is tuned for it.

| Style | Size / weight / line-height | Use |
|---|---|---|
| `displayId` | 26 / 500 / 1.2, letter-spacing 1.5 | remote-ID field value, your-desktop ID |
| `titleLg` | 18 / 700 / 1.4 | card titles ("کنترل دسکتاپ میزبان"), dialog titles |
| `titleMd` | 16 / 600 / 1.4 | nav labels at wide, tab labels, button labels in hero, settings section titles |
| `body` | 14 / 400 / 1.6 | prose, descriptions, menu items |
| `label` | 13 / 500 / 1.4 | button labels, chip labels, peer tile username |
| `caption` | 12 / 400 / 1.4 | version string, group headers ("تنظیمات"), helper text |
| `mono` | 14 / 500 / 1.4, tabular | IPs, ports, keys, logs |

**Digits.** `IRANSansXFaNum` draws ASCII digits as Persian numerals. That is
correct for prose and counts ("۵ جلسه") and **wrong** for identifiers. Add a
`RaatikTextStyles.identifier` style that uses a Latin-digit face (the non-FaNum
IRANSansX cut if licensed, otherwise `Roboto` / system) with
`FontFeature.tabularFigures()`. Apply it to: remote ID, your ID, password,
peer-tile ID, session tab ID, version, IP/port, hostnames.

**Grouping.** 9-digit IDs render as `107 292 347` (groups of three separated
by a regular space, never a comma). Longer IDs group from the right. Grouping is
display-only; copy gives the raw digits.

**Persian typography.** Use ZWNJ (نیم‌فاصله) in compounds (می‌شود, دفترچه‌ی,
علاقه‌مندی‌ها). Use Persian ی and ک, never Arabic ي/ك. Persian comma «،» and
Persian question mark «؟». No space before punctuation. Brand names stay Latin
("RaatikDesk") and are LTR-isolated.

### 1.7 Elevation and separation

- Default surfaces are flat. Separation uses a 1px border at about 12%
  foreground alpha and a surface step (card surface vs canvas).
- Tinted containers: the outer hero container and the active nav item use a
  brand tint at 8–14% alpha, optionally a diagonal gradient from 14% to 4%.
- Shadows only on things that float over content: the session toolbar
  cluster, menus, dialogs (`elevation 8`).
- Hover = surface tint +6%. Pressed = +12%. Focus = 2px ring in brand colour,
  same radius as the control. Disabled = 48% opacity, no hover.

### 1.8 Iconography

Material Icons, **rounded** variants where they exist, outlined when not
selected and filled when selected (nav already does this via
`RaatikSettingsDestination.selectedIcon`). Sizes per 1.4. Icon-only buttons get a
`Tooltip` and a `Semantics` label. No emoji as icons.

### 1.9 Motion

150–200ms, `Curves.easeOutCubic`. Hero dim when the service is stopped: 180ms
opacity (exists). Nav active indicator slides, tab pill slides, menus fade and
scale from their anchor. Nothing bounces. Respect reduced motion by dropping to
0ms.

### 1.10 State colour semantics (hues come from the Raatik palette)

| Meaning | Where |
|---|---|
| `success` dot | peer online, service ready, server reachable |
| `warning` dot | connecting, unknown, pending |
| `neutral` dot | offline, service stopped |
| `danger` | failed, destructive actions (close session) |

Dots are never the only signal; pair with text or a tooltip.

### 1.11 Numbers in RTL: display and input

Persian prose reads right-to-left, but every number a user might type into
another system is a left-to-right machine token. The UI must keep the two
apart without the user noticing. Four mechanisms do all the work:

| Mechanism | What it does | Where it lives |
|---|---|---|
| **LTR island** | A `Text` gets `ltrIsolate()` (U+2066 … U+2069); a field gets `ltrTextDirection()` around it. Never put isolate characters inside a `TextEditingController`. | `raatik/bidi/ltr_isolate.dart` |
| **Digit normalisation** | Persian (U+06F0–U+06F9) and Arabic-Indic (U+0660–U+0669) digits become ASCII on every edit and paste, before any other formatter runs. | `raatik/text/digits.dart` (`normalizeDigits`) |
| **Identifier style** | Latin-digit font with tabular figures, so the FaNum UI font does not turn digits Persian. | `RaatikTextStyles.identifier` |
| **Display grouping** | 3-3-3 grouping with regular spaces for IDs only, applied at render time; copy returns raw digits. | `formatID` / `trimID` |

**Classes of numbers and how each renders**

| Class | Examples | Digits | Direction | Style | Grouping |
|---|---|---|---|---|---|
| Identifier | remote ID, own ID, peer ID, session-tab ID | Latin | LTR island | `identifier` (26px `displayId` in the hero) | 3-3-3 |
| Secret | one-time password, permanent password, 2FA code | Latin | LTR island | `identifier`, masked by default | none |
| Network token | `193.176.243.102:21116`, `remote.raatik.ir`, URLs, ports | Latin | LTR island around the **whole** token | `mono` | none |
| Version | `1.4.9+128` | Latin | LTR island | `caption` | none |
| Technical quantity with Latin unit | `30 FPS`, `12 ms`, `1920×1080`, `4.2 MB`, `85 %` | Latin | LTR island around number **and** unit | `identifier` | none; Latin decimal point |
| Count or quantity in Persian prose | «۵ جلسهٔ فعال», «۳ دستگاه آنلاین», badge counts, «۲ دقیقه پیش» | Persian (FaNum font does it) | inline RTL | inherited | Persian separators «٬» «٫» if ever needed |
| Duration / clock | `00:12:34` | Latin | LTR island | `identifier` | none |
| Keyboard shortcut | `Ctrl+Alt+Del`, `F11` | Latin | LTR island | `caption` | none |
| Monitor index | `1 2 3` in the switcher | Latin | LTR | `identifier` | none |

Rule of thumb: if the user could type it somewhere else, it is Latin and
isolated. If it is only read as part of a sentence, it is Persian.

**Input fields that take numbers**

| Field | Direction | Alignment | Formatters (in this order) | Notes |
|---|---|---|---|---|
| Remote ID (hero) | LTR island | centre | normalise digits → strip grouping spaces and hyphens when the rest is digits → `IDTextInputFormatter` grouping | Hint is Persian: set `hintTextDirection: TextDirection.rtl`. Hostnames and `ip:port` must still pass through untouched (dots and colons are never stripped). Relay suffix `/r` or `\r` survives. |
| Own ID / password rows (read-only) | LTR island | centre | none | Copy uses `trimID` on the raw text. Hover reveals the masked password. |
| 2FA / verification code | LTR island | centre | normalise digits → allow `[0-9]` → length limit | Persian keyboard layouts type U+06F0–U+06F9; without normalisation the field silently rejects them. |
| Port, resolution, speed, FPS | LTR island | centre | normalise digits → allow `[0-9]` → length limit | Width tokens: 4 digits 64px, 5 digits 80px. |
| Server / relay / API address | LTR island | start of the island (left) | none | `mono`; Persian hint with `hintTextDirection: rtl`. |
| Search | RTL (prose) | start | none | Matching normalises digits so «۱۰۷» finds `107 292 347`. Digit runs stay LTR inside the RTL field by the bidi algorithm. |

**Caret, selection and keys inside an LTR island** behave as in an LTR app:
Home goes to the left end, the caret advances leftwards to rightwards. This is
expected and must not be "fixed" with reversed strings.

**Sliders and steppers.** Sliders follow the app direction (minimum at the
right in RTL); the numeric readout is an LTR island at the trailing (left) end
of the track. Steppers read «+» value «−» from left to right, i.e. the
increment button is on the left because increase points toward the trailing
edge.

**Numeric columns in tables** (file sizes, ports, latency) are LTR islands
aligned to the column's **end** edge (left in RTL) with tabular figures, so
units and last digits line up. Text columns stay start-aligned.

**Copy and compare.** Before copying or comparing an identifier, strip
isolate characters and grouping spaces (`trimID(stripBidiControls(text))`).
`ltrIsolate` is idempotent, so wrapping twice is harmless, but nested isolates
in a `TextEditingController` are a bug.

**Font mechanics.** The identifier and mono styles set an explicit
`fontFamily` with a Latin-digit face (`Segoe UI` with `Roboto`, `Helvetica
Neue`, `Arial` fallbacks; `Consolas` with `Menlo`, `monospace` for mono) and
`FontFeature.tabularFigures()`. An explicit family on a `TextStyle` overrides
the theme's FaNum family. Swapping in a bundled face later is a one-token
change.

---

## 2. Components

Each entry: anatomy in RTL reading order (right → left), sizes, states, and the
Flutter building block to reuse.

### 2.1 Window chrome

- Custom title bar height 40. Window controls at the OS side (right on Windows).
- Home window: title bar holds the brand (`RaatikWindowBrand`) at the leading
  (right) end on compact and medium. At wide the brand lockup lives in the
  sidebar header instead and the title bar stays empty.
- Session window: see 2.11.

### 2.2 Top bar (home)

Height 56, horizontal padding `space4`, two clusters. Nothing in the top bar
wraps.

Leading cluster (right): the **utility cluster**, one rounded container
(`radiusSm`, 1px border) holding, in order: service switch, server picker,
theme toggle, language, account.

| Class | Rendering |
|---|---|
| wide | icon + label, 1px dividers between items |
| medium | icon only, tooltip |
| compact | the cluster is replaced by one overflow icon button opening a menu with the same five items |

Trailing cluster (left): **help** button (filled square icon button,
`radiusSm`), **search** field (pill, min 160 / max 360, grows), **session
badge** (pill with count + clock, see 2.17), **power** (round outlined icon
button opening exit / restart).

Service switch states: `ready` → filled tint + success dot + "سرویس در حال اجرا
است"; `stopped` → outlined + play icon + "اجرای سرویس"; `starting` /
`connecting` → 16px spinner replaces the icon. The account entry is hidden
while `kRaatikApiEnabled == false`.

**Shrink order when space is scarce** (first to give way is listed first):
search field shrinks toward its 160 minimum → utility labels drop (wide →
medium rendering) → utility cluster collapses to the overflow button → help
button moves into the overflow menu. Session badge and power never move.
Worked compact case at a 490 window: content 426, minus `space4` gutters =
394; power 44 + badge 56 + overflow 44 + help 44 + four `space2` gaps 32 = 220,
leaving 174 for search, above its minimum.

### 2.3 Navigation rail (compact, medium)

Width `rail` (64), full height, 1px border on the trailing edge. Items are
**outlined square icon buttons** 44×44, `radiusSm`, stacked with `space2`
gaps, centred horizontally.

Order top → bottom: brand mark (logo only, 28px, not a button), then ارتباط
(home), پروفایل (hidden until the API ships), a `space4` gap, عمومی, امنیت,
شبکه, نمایش, چاپگر, درباره. Pinned to the bottom: فعال‌سازی بسته (licence,
accent outline) and **service status** (server icon with a `dot` at its
bottom-start corner reflecting `RaatikServicePhase`).

Active item: brand tint fill (14%), icon in brand colour, a 3×20 indicator bar
on the **trailing** (left) edge inside the item. Hover: tint 6%. Tooltip on all.

### 2.4 Navigation sidebar (wide)

Width `sidebar` (232), padding `space4`. Contents top → bottom:

1. Brand lockup: logo 36 + Persian wordmark `titleLg` + Latin "RaatikDesk" in
   `caption` with 2px letter-spacing underneath.
2. **Your desktop panel** (2.7), full width.
3. Nav items, each an **outlined button row** 44 high, `radiusSm`, 1px border,
   icon 20 at the leading side, label `titleMd` start-aligned, `space3` gap.
   Active: brand tint fill, brand border, a chevron ‹ at the trailing end.
4. Group header "تنظیمات" in `caption`, muted, `space4` above, `space2` below.
5. Settings items (same row style).
6. Spacer, then فعال‌سازی بسته (accent outline, key icon), then the version
   string in `caption`, LTR-isolated: `نسخه: 1.4.9+128`.

Selecting a settings item swaps the content area in place (single window).
Until the settings page is embedded, opening the existing settings window from
these items is acceptable, but the items must exist in the sidebar.

### 2.5 Hero container

Outer container: `radiusXl`, 1px border, brand tint gradient (14% → 4%
diagonal), padding `space3`. It holds the **connect card** and the **your
desktop card**.

| Class | Arrangement |
|---|---|
| compact | Column: connect card, `space3`, your-desktop card |
| medium | Row: connect card (flex 10) leading, `space3`, your-desktop card (flex 9) trailing |
| wide | Only the connect card, centred, max `heroMax`, with illustration and subtitle. Your-desktop moves to the sidebar. |

The hero is the first thing under the top bar, with a `space4` gutter around it.

**Deliberate reversal.** Upstream RustDesk shows "your desktop" first and the
connect field second. RaatikDesk inverts this on purpose: the user's own ID is
read once per session, the remote ID is typed every session. Do not restore the
upstream order for familiarity.

### 2.6 Connect card ("کنترل دسکتاپ میزبان")

Surface card, `radiusLg`, padding `space5` (compact `space4`).

Anatomy, top → bottom:

1. Title row: optional overline chip "ارتباط" (wide only), title `titleLg`
   start-aligned. At wide an illustration (120×120) sits at the leading side
   of the title and subtitle block.
2. Subtitle `body` muted, wide only: "برای دسترسی به دسکتاپ دیگران شناسه را
   اینجا وارد کنید".
3. **Remote ID field**: height `heroInput`, `radiusSm`, filled surface, 1px
   border, value centred in `displayId` with live 3-3-3 grouping, Latin
   digits, LTR. Placeholder "شناسه راه دور" in `body` muted (Persian, RTL).
   Accepts paste with any separators. Autocomplete of recent peers below.
4. Action row (`space3` above): **primary CTA** "اتصال", flex 1, height
   `heroInput`, filled brand, label `titleMd` white, a ← arrow icon after the
   label (icon-after in RTL, arrow points left). Then a **more button** 52×52
   outlined square (`radiusSm`, "⋯") at the trailing end opening: ارسال/دریافت
   فایل, مشاهده دوربین, ترمینال, پورت‌فورواردینگ, اتصال با RDP.

States: CTA disabled (48%) while the field is empty or the service is not
ready; CTA shows a 20px spinner and "در حال اتصال…" while connecting; field
gets a danger border and helper "شناسه معتبر نیست" on invalid input.

### 2.7 Your desktop card ("دسکتاپ شما")

Surface card, `radiusLg`, padding `space4`. In the sidebar (wide) it is the same
widget at sidebar width.

1. Title row: title `titleLg`, and at the trailing end a 36×36 tinted square
   (`radiusXs`) with a monitor icon.
2. **ID row** (height 44, filled field look, `radiusSm`): label chip "شناسه" at
   the leading edge (2.17), value centred `displayId` (20px at sidebar width),
   trailing actions: copy icon button, kebab (⋮) opening ID settings.
3. **Password row** (same frame): label chip "رمز عبور", value centred (masked
   by default, "-" when none), trailing actions: refresh (new one-time
   password), copy, kebab (password settings). Hover reveals the value.

Row internals: a `Row` with the value `Expanded` and centred so chips and
actions never push it off-centre.

### 2.8 Service gate

`RaatikServiceGate` stays as the blocking banner above the hero when the phase
is `stopped` or `failed` (full-width card, `radiusLg`, warning or danger tint,
title + body + "اجرای سرویس" button). While blocked the hero dims to 48% and
absorbs pointer (exists in `RaatikHomeLayout`). The gate is **not** shown when
`ready`; the utility cluster and the rail dot carry the state instead.

### 2.9 Peer tab bar

One rounded container (`radiusLg`, 1px border, padding `space1`), height 52.
Leading side: tabs. Trailing side: view toggles.

Tabs in order: آخرین اتصالات (clock), اتصالات دلخواه (star), پیدا شده (compass),
دفترچه آدرس (book, hidden while the API is disabled), گروه (hidden while the API
is disabled). Each tab: icon 20 + label `titleMd`, horizontal padding `space4`,
height 44. Active tab: `radiusPill` filled brand tint with brand-colour icon
and label. Inactive: transparent, muted. Tabs scroll horizontally in compact;
the active tab is kept visible.

Trailing toggles (icon buttons 36×36, `radiusXs`): view switcher (grid / list)
and multi-select mode (checkbox icon). Sort appears only on non-recent tabs
(exists).

### 2.10 Peer tile (grid) and peer row (list)

**Tile**: `radiusLg`, 1px border, clipped. Width from the max-extent grid
(≤ 220), height `tileHeader + tileFooter` = 136 (+ 8 when a tag row exists).

- Header (96): background is a muted hue derived from `hash(peer.id) % 12`
  over a fixed 12-step hue ring at constant saturation and lightness, so every
  tile reads as one family. Centred platform glyph 48 in white, and the
  `user@host` string under it in `label` white, single line, ellipsis,
  LTR-isolated.
- Footer (40): surface colour. Leading side: **status dot** (10px), then the
  ID (`identifier` style, grouped) or the alias if one exists. Trailing side:
  kebab (⋮) 36×36 opening the peer menu. Tags, if any, render as 6px dots
  after the status dot.
- Hover: border becomes brand, header gains a 6% light overlay, pointer
  cursor. The whole tile is the click target; the kebab stops propagation.
- Selected (multi-select mode): checkbox 20px at the header's top-leading
  corner, 2px brand border.

**Row** (list view): height 56, same anatomy horizontally: dot → platform
icon 24 in a 40×40 hued square (`radiusXs`) → alias / ID (`label`) over
`user@host` (`caption`) → spacer → kebab.

Grid: `space3` gaps, `space4` gutter, scrollbar on the left. Empty state: icon
48 muted + one line of `body` ("هنوز اتصالی ثبت نشده است").

Column count is never hard-coded. With `w` = content width (window minus rail or
sidebar) the grid delegate yields
`columns = ceil((w - 2*space4 + space3) / (tileMaxExtent + space3))` and tiles
stretch to fill. Worked values: 490 window → 426 content → 2 columns of 191;
760 → 696 → 3 columns of 216; 1600 → 1368 → 6 columns of 218. If a tile would
fall under 180 (content narrower than 388), drop to 1 column.

### 2.11 Session window header

Height `toolbarBar` (48), full width, surface colour, bottom border. This bar
is **intentionally not mirrored**: OS window controls stay right, so the toolbar
cluster sits next to them and tabs grow from the left.

Left → right: **new connection** button (outlined pill, "+ اتصال جدید"), brand
(`RaatikWindowBrand`, logo + name), then **session tabs**. Right → left: window
controls, then the **session toolbar cluster** (2.12) when the window is
maximised or the toolbar is pinned.

Session tab: height 36, `radiusSm`, 1px border (brand when active), padding
`space3`, contents in RTL reading order: status dot 8 → monitor / file /
terminal glyph 16 → ID (`identifier`, grouped) → close ✕ on hover at the
trailing end. Min 120 / max 200 wide.

### 2.12 Session toolbar cluster

A floating container (`radiusLg`, brand background, elevation 2, padding
`space1`) that docks top-centre over the remote frame, or into the header when
maximised. Contents are 36×36 icon buttons (`radiusXs`, `space1` gaps), white
glyphs, each with a tooltip.

Right → left: close session (danger fill, ✕) · fullscreen · recording (shows a
"●REC" label while recording) · chat · keyboard / input menu · display menu ·
actions menu (⚡: Ctrl+Alt+Del, lock, restart, privacy mode) · **monitor
switcher**.

Monitor switcher: a segmented control inside the cluster, one 28×28 segment per
monitor labelled with its number (`identifier`), active segment filled white
with brand text. Hidden when the peer has one monitor; "all monitors" is the
trailing segment when supported.

Collapsed state: a 24px grab handle (existing `_DraggableShowHide` pattern)
that expands the cluster on hover or click. Keyboard: the cluster is one focus
group; arrow keys move between buttons.

### 2.13 Menus (session and elsewhere)

Anchored under their button, `radiusSm`, 1px border, elevation 8, width
280–360, vertical padding `space2`. Item height 40, horizontal padding
`space4`, text `body` start-aligned.

- **Radio items**: radio glyph 20 at the leading (right) edge, label after it.
- **Check items**: checkbox 20 (`radiusXs`) at the leading edge, filled brand
  when checked.
- **Submenu items**: label at start, chevron ‹ (pointing left, toward where
  the submenu opens) at the trailing edge. Submenus open toward the trailing
  side and flip when there is no room.
- Dividers 1px with `space2` above and below, between groups: scale →
  quality / codec / resolution → cursor options → monitor / clipboard /
  privacy options.
- Keyboard shortcuts, when shown, at the trailing edge in `caption`, LTR.

### 2.14 Dialogs

`radiusLg`, elevation 8, padding `space6`, width 360 for confirmations and
`dialogMax` 560 for forms. Title row: 20px icon at the leading edge + `titleLg`.
Body `body`. Actions row at the bottom, **end-aligned** (left in RTL), primary
button at the **outermost (leftmost)** position, secondary to its right,
`space2` gap, buttons 44 high with a leading icon (✓ on confirm, ✕ on cancel).
Escape = cancel, Enter = primary. The underlying content stays visible at 40%
dim. Use `raatikDialogActions` and `RaatikDialogStyle`.

Canonical: the password prompt. Title "رمز عبور لازم است" with a ••• icon,
body "رمز عبور RaatikDesk را تایید کنید", password field (lock icon leading,
eye toggle trailing, autofocus), checkbox "رمز عبور را به خاطر بسپار" with the
box at the leading edge, actions "قبول ✓" primary / "لغو ✕" secondary.

### 2.15 Buttons

| Kind | Look | Height |
|---|---|---|
| Primary | filled brand, white `titleMd` label, optional icon after the label | 44 (52 in hero) |
| Secondary | 1px outline, foreground label | 44 |
| Ghost | no border, tint on hover | 44 |
| Icon square | 1px outline, `radiusSm`, icon 20 | 44×44 (52 next to the hero CTA, 36 inside clusters) |
| Icon round | 1px outline, `radiusPill` | 44 |
| Destructive | danger outline; filled only for the session close button | 44 |

Icon placement: the icon follows the label in RTL ("اتصال ←"), gap `space3`.
Loading: the spinner replaces the icon and the label changes to the
progressive form ("در حال اتصال…").

### 2.16 Text fields

Height 44 (52 hero), `radiusSm`, filled surface, 1px border, focus 2px brand.
Leading icon (right) carries meaning (lock, search); trailing icon (left)
carries actions (eye, clear, copy). Label chips (2.17) may replace the leading
icon in read-only rows. The search field is a pill with a search icon leading
and the placeholder "جستجو". Errors: danger border + `caption` helper under the
field, start-aligned.

### 2.17 Chips, badges, dots

- **Label chip**: `radiusXs`, 24 high, brand tint 12%, `label` text in brand.
  Used for "شناسه", "رمز عبور", "ارتباط". Non-interactive.
- **Count badge**: pill 32 high, outlined, number (`identifier`) + icon, for
  example the active-sessions badge in the top bar.
- **Status dot**: 8px (10 in tiles), semantic colour (1.10), 1px surface ring
  when on coloured backgrounds. Always with a tooltip naming the state.
- **Tag dots**: 6px, peer tags, up to 4 then "+N".

### 2.18 Settings page

Uses `RaatikSettingsShell`. At wide the shell is the home sidebar itself and
sections swap in place; at narrower widths a compact header with a destination
picker. Content column max 720. Sections are cards (`radiusLg`, padding
`space5`) with a `titleMd` title and rows 44 high: label at start, control
(switch / dropdown / field) at end. Dangerous settings get a danger outline and
a confirm dialog.

---

## 3. Writing (Persian UI copy)

- Reuse keys from `src/lang/fa.rs`; add new keys there, never hard-code Persian
  in Dart.
- Titles are noun phrases ("دسکتاپ شما"), buttons are imperatives ("اتصال",
  "قبول"), progressive labels use "در حال …".
- Numbers in prose use Persian digits; identifiers use Latin digits (1.6).
- Brand: "RaatikDesk" in Latin, LTR-isolated, or "راتیک‌دسک" with ZWNJ when a
  Persian form is required. Never mix both on one screen.
- Keep labels at 18 characters or fewer so they fit the sidebar and tabs at
  16px.

---

## 4. Token proposal (Dart)

Extend `flutter/lib/raatik/theme/tokens.dart`; existing names stay valid.

```dart
class RaatikTokens {
  RaatikTokens._();

  // colour (unchanged: RaatikDesk palette)
  static const primary = Color(0xFF0284C7);
  static const accent = Color(0xFF0891B2);
  static const success = Color(0xFF059669);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const lightCanvas = Color(0xFFF4F7FB);
  static const darkCanvas = Color(0xFF111827);

  // spacing (4-based)
  static const space1 = 4.0, space2 = 8.0, space3 = 12.0, space4 = 16.0;
  static const space5 = 20.0, space6 = 24.0, space8 = 32.0;
  static const spaceXs = space1, spaceSm = space2, spaceMd = space3;
  static const spaceLg = space4, spaceXl = space5, iconLabelGap = space3;

  // radius
  static const radiusXs = 8.0, radiusSm = 12.0, radiusLg = 16.0;
  static const radiusXl = 20.0, radiusPill = 999.0;

  // sizes
  static const minTarget = 44.0, heroInput = 52.0, toolbarBtn = 36.0;
  static const toolbarBar = 48.0, rail = 64.0, sidebar = 232.0;
  static const heroMax = 640.0, dialogMax = 560.0, confirmDialogMax = 360.0;
  static const tileMaxExtent = 220.0, tileHeader = 96.0, tileFooter = 40.0;
  static const iconSm = 16.0, iconMd = 20.0, iconLg = 24.0, glyph = 48.0;
  static const dot = 8.0, contentMaxWidth = 1440.0;

  // breakpoints
  static const compactMax = 640.0, mediumMax = 1200.0;

  // motion
  static const motion = Duration(milliseconds: 180);
  static const curve = Curves.easeOutCubic;

  static const inputContentPadding =
      EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12);
}
```

Text styles live in a new `RaatikTextStyles` (`displayId`, `titleLg`,
`titleMd`, `body`, `label`, `caption`, `identifier`, `mono`) built from
`Theme.of(context).textTheme` so light and dark colours stay correct.

---

## 5. Acceptance checklist (every UI change)

Run at 480, 900 and 1600 px wide, light and dark, language `fa`.

- [ ] Layout matches the blueprint in `SCREENS.md` for that width class.
- [ ] No `left` / `right` / `TextDirection.ltr` used for layout; only
      directional APIs (grep the diff).
- [ ] Every ID, host, version and path is LTR-isolated and uses the
      `identifier` style with Latin digits and 3-3-3 grouping.
- [ ] Every field that accepts digits normalises Persian and Arabic-Indic
      digits first (type «۱۲۳» and see `123`), and copying an identifier
      yields raw digits with no spaces or isolate characters.
- [ ] Counts inside Persian sentences render in Persian digits; nothing a
      user could type elsewhere does.
- [ ] Every interactive element is at least 44px (36 inside a cluster), has
      hover, a focus ring, a tooltip if icon-only, and a disabled look.
- [ ] Nested radii step 20 → 16 → 12 → 8; no other radius values.
- [ ] Only spacing-scale values; no 5, 6, 10, 15 or 18 px.
- [ ] Dialog actions end-aligned, primary outermost, Enter and Escape wired.
- [ ] Status shown by a dot **and** text or tooltip.
- [ ] Persian strings come from `fa.rs`, use ZWNJ and Persian ی / ک.
- [ ] The hero CTA and ID field are the largest controls on the home screen.
- [ ] Screenshots of all three widths attached to the change.
