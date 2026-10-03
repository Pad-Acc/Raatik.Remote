# RaatikDesk Screen Blueprints

Companion to `DESIGN-SYSTEM.md`. Diagrams are drawn **as rendered in RTL**: the
right edge is the leading edge. Token names refer to section 4 of the design
system. Widths named `compact / medium / wide` follow section 1.5.

---

## 1. Home window

### 1.1 Compact (< 640, e.g. 480×680)

```
┌──────────────────────────────────────────────┬────┐
│ title bar: [RaatikDesk ●]                     │    │  40
├──────────────────────────────────────────────┤ ●  │  ← brand mark
│ [⏻] [5 ◷] [ 🔍 جستجو          ] [≡]   [📖]    │▐▯▌ │  56  top bar
├──────────────────────────────────────────────┤    │
│ ╔══════════ hero container (radiusXl) ═════╗ │ ▯  │
│ ║ ┌─ connect card ───────────────────────┐ ║ │ ▯  │
│ ║ │                 کنترل دسکتاپ میزبان  │ ║ │ ▯  │
│ ║ │ ┌──────────────────────────────────┐ │ ║ │ ▯  │
│ ║ │ │          107 292 347             │ │ ║ │ ▯  │  heroInput 52
│ ║ │ └──────────────────────────────────┘ │ ║ │ ▯  │
│ ║ │ [⋯] [        ← اتصال               ] │ ║ │    │  52
│ ║ └──────────────────────────────────────┘ ║ │    │
│ ║ ┌─ your desktop card ──────────────────┐ ║ │    │
│ ║ │ [▣]                      دسکتاپ شما  │ ║ │    │
│ ║ │ [⋮][⧉]     231 339 258      (شناسه)  │ ║ │    │  44
│ ║ │ [⋮][⧉][↻]       -         (رمز عبور) │ ║ │    │  44
│ ║ └──────────────────────────────────────┘ ║ │ 🔑 │
│ ╚══════════════════════════════════════════╝ │ ▣● │  ← service dot
├──────────────────────────────────────────────┤    │
│ [▦][☑]   پیدا شده ◎  علاقه‌مندی‌ها ★ (◷ آخرین اتصالات) │  52  tabs scroll
├──────────────────────────────────────────────┤    │
│ ▏ ┌────────────┐ ┌────────────┐              │    │
│ ▏ │  ⊞ header  │ │  ⊞ header  │  2 columns   │    │  96
│ ▏ │ user@host  │ │ user@host  │              │    │
│ ▏ │[⋮] 459 738 116 ●│[⋮] 107 292 347 ●│        │    │  40
│ ▏ └────────────┘ └────────────┘              │    │
└──────────────────────────────────────────────┴────┘
```

- The right-hand column is the 64px **icon rail** (DESIGN-SYSTEM 2.3), the
  same at compact and medium: brand mark, home (active, with the trailing
  indicator bar), then the settings group, and pinned to the bottom the
  licence key and the service-status icon with its dot. The rail never holds
  the your-desktop panel; that only happens in the wide sidebar.
- Content width at a 490 window is therefore 426.
- Utility cluster is collapsed into the `[≡]` overflow button.
- Hero cards stacked; gutter `space4`; cards `space3` apart.
- Tabs: icon + label, horizontally scrollable, active pill kept in view.
- Grid: 2 columns, `space3` gaps. Scrollbar on the left (`▏`).

### 1.2 Medium (640–1199, e.g. 760×660)

```
┌───────────────────────────────────────────────────────────┬────┐
│ title bar: [RaatikDesk ●]                                  │ ●  │
├───────────────────────────────────────────────────────────┤    │
│ [⏻][5 ◷][ 🔍 جستجو      ] [📖]      [⇥][🌐][☾][▶]           │▐▯▌ │ utility = icons
├───────────────────────────────────────────────────────────┤ ▯  │
│ ╔═══════════════════════════════════════════════════════╗ │ ▯  │
│ ║ ┌─ your desktop (flex 9) ─┐ ┌─ connect (flex 10) ────┐ ║ │ ▯  │
│ ║ │ [▣]        دسکتاپ شما   │ │     کنترل دسکتاپ میزبان │ ║ │ ▯  │
│ ║ │ [⋮][⧉] 231 339 258 (شناسه)│ │ ┌────────────────────┐ │ ║ │ ▯  │
│ ║ │ [⋮][⧉][↻]  -  (رمز عبور) │ │ │    107 292 347     │ │ ║ │    │
│ ║ │                         │ │ └────────────────────┘ │ ║ │    │
│ ║ │                         │ │ [⋯] [   ← اتصال      ] │ ║ │ 🔑 │
│ ║ └─────────────────────────┘ └────────────────────────┘ ║ │ ▣● │
│ ╚═══════════════════════════════════════════════════════╝ │    │
├───────────────────────────────────────────────────────────┤    │
│ [▦][☑]  دفترچه آدرس 📖  پیدا شده ◎  علاقه‌مندی‌ها ★ (◷ آخرین اتصالات) │
├───────────────────────────────────────────────────────────┤    │
│ ▏ [tile] [tile] [tile]   auto-fit, maxExtent 220          │    │
│ ▏ [tile] [tile] [tile]                                    │    │
└───────────────────────────────────────────────────────────┴────┘
```

- Connect card is the **leading** (right) card; your-desktop is trailing.
- Utility cluster icon-only with tooltips.

### 1.3 Wide (≥ 1200, e.g. 1600×900)

```
┌──────────────────────────────────────────────────────────────┬──────────────┐
│ title bar (empty)                                             │  ● راتیک‌دسک │
├──────────────────────────────────────────────────────────────┤  RaatikDesk  │
│ [⏻][5 ◷][ 🔍 جستجو            ][📖 آموزش]  [⇥ ورود|🌐 فارسی|☾ تیره|● سرورها|▶ اجرای سرویس] │
├──────────────────────────────────────────────────────────────┤ ┌──────────┐ │
│                                                              │ │دسکتاپ شما│ │
│          ┌──── connect card, max 640, centred ─────┐         │ │231 339 258│ │
│          │ (ارتباط)                      ┌──────┐  │         │ │   -   ↻  │ │
│          │ کنترل دسکتاپ میزبان            │ illus│  │         │ └──────────┘ │
│          │ برای دسترسی به دسکتاپ دیگران … └──────┘  │         │ ‹ ارتباط  ⛶ │ active
│          │ ┌────────────────────────────────────┐   │         │   پروفایل ◯ │
│          │ │             459 738 116            │   │         │ تنظیمات      │ caption
│          │ └────────────────────────────────────┘   │         │   عمومی   ⚙ │
│          │ [⋯] [            ← اتصال              ]  │         │   امنیت   🔒 │
│          └──────────────────────────────────────────┘         │   شبکه    🔗 │
├──────────────────────────────────────────────────────────────┤   نمایش   ▣ │
│ [▦][☑]   دفترچه آدرس 📖   پیدا شده ◎   علاقه‌مندی‌ها ★  (◷ آخرین اتصالات) │   چاپگر   🖶 │
├──────────────────────────────────────────────────────────────┤   درباره  ⓘ │
│ ▏ [tile][tile][tile][tile][tile][tile][tile]  7–8 columns    │              │
│ ▏ [tile][tile][tile][tile][tile][tile][tile]                 │ 🔑 فعال‌سازی │
│ ▏                                                            │ نسخه 1.4.9+128│
└──────────────────────────────────────────────────────────────┴──────────────┘
```

- Sidebar 232 wide replaces the rail; it carries brand lockup, your-desktop
  panel, nav + settings entries, licence entry, version.
- Hero container is reduced to the single centred connect card (the outer
  tint container still wraps it).
- Content column (top bar + hero + peers) is capped at `contentMaxWidth`
  (1440) and centred when the window is wider.

### 1.4 Service stopped (any width)

```
┌─ service gate (warning tint, radiusLg) ───────────────────────┐
│ [اجرای سرویس ▶]   سرویس متوقف است. برای اتصال، سرویس را اجرا کنید │
└────────────────────────────────────────────────────────────────┘
╔═ hero at 48% opacity, pointer absorbed ═╗
```

The gate sits between the top bar and the hero. The rail / sidebar service
dot turns neutral; the utility cluster service switch shows the outlined
"اجرای سرویس" state.

---

## 2. Peer tile and row

```
tile (≤220 × 136)                 row (56 high)
┌──────────────────────┐          ┌──────────────────────────────────────┐
│   hued header (96)   │          │ [⋮]   user@host     Mina ●           │
│         ⊞ 48         │          │       ⧉ 24 in 40×40 hued square      │
│  Mina@desktop-vq4n…  │          └──────────────────────────────────────┘
├──────────────────────┤
│ [⋮]      107 292 347 ● │  footer 40
└──────────────────────┘
```

Reading order inside the footer (right → left): status dot, ID or alias, then
the kebab at the far left. Alias replaces the ID when set; the ID moves to the
tooltip.

---

## 3. Session window

### 3.1 Header (maximised or pinned)

```
┌────────────────────────────────────────────────────────────────────────────────┐
│ [+ اتصال جدید] [● RaatikDesk] [● ▣ 107292347 ✕]   …   [1|2|3][⚡][▣][⌨][💬][●REC][⛶][✕]  – ▢ ✕ │ 48
└────────────────────────────────────────────────────────────────────────────────┘
   left: new-connection, brand, tabs →            ← right: toolbar cluster, window controls
```

This bar is not mirrored (see design system 2.11).

### 3.2 Floating toolbar (windowed)

```
            ┌───────────────────────────────────────────────┐
            │ [1|2|3] [⚡] [▣] [⌨] [💬] [●REC] [⛶] [✕]        │  radiusLg, 44 tall
            └───────────────────────────────────────────────┘
                       ▽ grab handle when collapsed
```

Order as read right → left: ✕ close, ⛶ fullscreen, ●REC, 💬 chat, ⌨ keyboard,
▣ display, ⚡ actions, [monitor switcher].

### 3.3 Display menu (anchored under ▣)

```
┌──────────────────────────────┐
│          مقیاس اصلی       ◯  │  radio, 40 high
│         مقیاس تطبیقی      ◉  │
│         مقیاس دلخواه      ◯  │
├──────────────────────────────┤
│ ‹            کیفیت تصویر     │  submenu, chevron trailing
│ ‹                   کدک     │
│ ‹                  وضوح     │
├──────────────────────────────┤
│   نمایش مکان‌نمای میزبان  ☑  │  check, box leading
│   دنبال‌کردن مکان‌نمای ریموت ☐ │
│   بزرگ‌نمایی نشانگر ماوس  ☐  │
├──────────────────────────────┤
│   نمایش کیفیت مانیتور     ☐  │
│   اجازهٔ کپی و چسباندن فایل ☑│
│   غیرفعال‌سازی کلیپ‌بورد   ☐  │
│   قفل حساب پس از خروج     ☐  │
│   همهٔ نمایشگرها          ☐  │
│   حالت حریم خصوصی         ☐  │
└──────────────────────────────┘
```

Width 320. Submenus open to the left (trailing).

---

## 4. Dialogs

### 4.1 Password prompt (360 wide)

```
┌──────────────────────────────────────────┐
│                  رمز عبور لازم است  •••  │  titleLg + icon leading
│          رمز عبور RaatikDesk را تایید کنید │  body
│ ┌──────────────────────────────────────┐ │
│ │ 👁                      رمز عبور  🔒 │ │  44, focused border
│ └──────────────────────────────────────┘ │
│              رمز عبور را به خاطر بسپار ☐ │  checkbox leading
│                                          │
│ [✓ قبول] [✕ لغو]                         │  end-aligned, primary outermost
└──────────────────────────────────────────┘
```

### 4.2 Confirmation (360 wide)

Same frame: icon + title, one body line, two actions. Destructive confirms
use a danger primary.

### 4.3 Form dialogs (560 wide)

Same frame with a scrollable body; rows 44 high, label start / control end.

---

## 5. Settings

### 5.1 Wide (inside the home window)

```
┌───────────────────────────────────────────────┬──────────────┐
│  ┌─ section card (max 720, centred) ────────┐ │ sidebar      │
│  │ عمومی                                    │ │ (same as 1.3,│
│  │ [▾ تیره]                      پوسته       │ │ active item  │
│  │ [▾ فارسی]                     زبان رابط   │ │ = عمومی)     │
│  │ [●  ]            اجرای خودکار با ویندوز    │ │              │
│  └──────────────────────────────────────────┘ │              │
│  ┌─ next section card ─────────────────────┐  │              │
└───────────────────────────────────────────────┴──────────────┘
```

### 5.2 Compact and medium

`RaatikSettingsShell` compact header (56) with a destination dropdown, then
the same section cards full width with `space4` gutter.

---

## 6. Component-to-code map

| Blueprint element | Reuse / create |
|---|---|
| Home layout per width | `RaatikHomeLayout` (update breakpoints, add wide variant) |
| Rail / sidebar | new `RaatikNavRail`, `RaatikNavSidebar`; destinations from `RaatikSettingsDestination` |
| Top bar | new `RaatikHomeTopBar`, `RaatikUtilityCluster` |
| Hero container, connect card, your-desktop card | new `RaatikHeroContainer`, `RaatikConnectCard`, `RaatikYourDesktopCard`; wire to existing `ConnectionPage` logic |
| Service gate | `RaatikServiceGate` (exists) |
| Peer tabs | restyle `PeerTabPage` tab row |
| Peer tile / row | restyle `_PeerCard` in `peer_card.dart`; keep `PeerUiType` |
| Session header and tabs | `remote_tab_page.dart`, `tabbar_widget.dart` |
| Toolbar cluster | `RaatikRemoteToolbarBar` + `_IconMenuButton` in `remote_toolbar.dart` |
| Menus | `material_mod_popup_menu.dart`, `popup_menu.dart` |
| Dialogs | `dialog.dart` + `RaatikDialogStyle` |
| Settings | `RaatikSettingsShell` + `desktop_setting_page.dart` |
| Bidi and numbers | `ltr_isolate.dart`, `raatik/text/digits.dart`, `raatik/text/identifier_widgets.dart`, `common/formatter/id_formatter.dart` |
| Text styles | `raatik/theme/text_styles.dart` (`RaatikTextStyles`) |
