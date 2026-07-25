# RaatikDesk UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship RaatikDesk **2026.07.01** with RTL Farsi UI, IRANSansXFaNum, Raatik theme, B1 home, settings IA, T1 remote toolbar, API surfaces hidden, admin elevation, and a Flutter web preview harness — without rewriting the remote-desktop engine.

**Architecture:** Approach 1 from the spec — keep FFI/models; replace `MyTheme` tokens, register IRANSansXFaNum, force RTL for `fa`, rewrite home/settings/toolbar presentation, gate API UI with `kRaatikApiEnabled`, bump release version, verify via preview + CI Actions.

**Tech Stack:** Flutter 3.24.5 (desktop + Chrome preview), Rust 1.75 / existing bridge, GitHub Actions `raatik-windows` / `raatik-check`, IRANSansXFaNum TTFs under `flutter/assets/`.

**Spec:** [2026-07-26-raatikdesk-ui-redesign-design.md](../specs/2026-07-26-raatikdesk-ui-redesign-design.md). Branch: `raatik/ui-2026.07.01`.

## Global Constraints

- **Product name in UI chrome:** `RaatikDesk` (Latin only). Farsi sentences may say «برنامه».
- **Release display / CI artifact version:** `2026.07.01` → `RaatikDesk-2026.07.01-install.exe`.
- **Semver for Cargo + pubspec (no leading zeros):** `2026.7.1` / Flutter `2026.7.1+20260701`.
- **Audience:** customers first; support second. Home B1; toolbar T1; settings groups per spec §7.
- **API:** `kRaatikApiEnabled = false` — hide login/cloud AB; do not redesign those screens.
- **Font:** IRANSansXFaNum only for UI text. **RTL** when locale is Farsi.
- **Colors:** Primary `#0284C7`, Accent `#0891B2`, Surface `#F8FAFC`, Text `#0F172A` (light); dark counterparts per spec §5.1.
- **Admin:** `requireAdministrator` on Windows manifests (UAC every cold start).
- **Remove tip:** `setup_server_tip` must not appear in UI.
- **Never edit** `src/lang/template.rs`. **Never rename** package `rustdesk` / `librustdesk`.
- **Preserve** AGPL `LICENCE` and copyright headers.
- **Shipping builds:** GitHub Actions only. Local UI check = Flutter Chrome preview harness (Flutter SDK optional on this machine).
- Follow `AGENTS.md`: smallest valid diff; no unrelated refactors.

## File Structure

| Path | Responsibility |
|---|---|
| `Cargo.toml`, `libs/portable/Cargo.toml` | Package version `2026.7.1` |
| `flutter/pubspec.yaml` | Version + IRANSansXFaNum font family |
| `.github/workflows/raatik-windows.yml` | `VERSION: "2026.07.01"`; optionally trigger branch |
| `.github/workflows/raatik-check.yml` | Allow branch `raatik/ui-2026.07.01` |
| `res/manifest.xml`, `flutter/windows/runner/runner.exe.manifest` | UAC `requireAdministrator` |
| `flutter/assets/logo.png` (+ ico sources under `res/` / `runner/resources/`) | In-window + taskbar Raatik mark |
| `flutter/lib/common.dart` | `MyTheme` tokens, default `fontFamily`, RTL/`TextDirection` helpers |
| `flutter/lib/consts.dart` or new `flutter/lib/raatik/flags.dart` | `kRaatikApiEnabled` |
| `flutter/lib/main.dart` / desktop theme wrap | Apply font + Directionality |
| `flutter/lib/desktop/pages/desktop_home_page.dart` | B1 layout |
| `flutter/lib/desktop/pages/connection_page.dart` | Connect panel + remove tip |
| `flutter/lib/desktop/pages/desktop_setting_page.dart` | Settings IA + hide API |
| `flutter/lib/desktop/widgets/remote_toolbar.dart` | T1 top bar |
| `flutter/lib/common/widgets/login.dart` (call sites) | Gate behind flag — no redesign |
| `src/lang/fa.rs`, `src/lang/en.rs` | Meaningful Farsi; empty/remove tip; brand leftovers |
| `flutter/lib/preview_main.dart` (+ `flutter/lib/preview/`) | Chrome UI harness |
| `raatik/no_leak_gate.py` | Keep/extend leak checks for new copy |

---

### Task 1: Version bump to 2026.07.01

**Files:**
- Modify: `Cargo.toml` (root `version`)
- Modify: `libs/portable/Cargo.toml` (`version`)
- Modify: `flutter/pubspec.yaml` (`version:`)
- Modify: `.github/workflows/raatik-windows.yml` (`env.VERSION`)
- Modify: `.github/workflows/raatik-check.yml` (branch filter)

**Interfaces:**
- Produces: artifact name `RaatikDesk-2026.07.01-install.exe`; About/package semver `2026.7.1`.

- [ ] **Step 1: Set Cargo versions**

In `Cargo.toml` and `libs/portable/Cargo.toml`:

```toml
version = "2026.7.1"
```

- [ ] **Step 2: Set Flutter version**

In `flutter/pubspec.yaml`:

```yaml
version: 2026.7.1+20260701
```

- [ ] **Step 3: Set CI display VERSION**

In `.github/workflows/raatik-windows.yml`:

```yaml
VERSION: "2026.07.01"
```

- [ ] **Step 4: Allow check workflow on this branch**

In `.github/workflows/raatik-check.yml`, ensure `push`/`pull_request` branches include `raatik/ui-2026.07.01` (keep `raatik/1.4.9` too).

- [ ] **Step 5: Commit**

```bash
git add Cargo.toml libs/portable/Cargo.toml flutter/pubspec.yaml .github/workflows/raatik-windows.yml .github/workflows/raatik-check.yml
git commit -m "$(cat <<'EOF'
build: set RaatikDesk release version to 2026.07.01

EOF
)"
```

---

### Task 2: Font, theme tokens, RTL, logo assets

**Files:**
- Modify: `flutter/pubspec.yaml` (fonts section)
- Modify: `flutter/lib/common.dart` (`MyTheme` color constants ~250–270 and `ThemeData` `fontFamily`)
- Modify: `flutter/lib/main.dart` (wrap MaterialApp builder with Directionality when locale is fa)
- Replace: `flutter/assets/logo.png` from repo `../raatik-logo.png` (crop/export square mark without black letterbox if needed)
- Replace: `res/icon.png`, `flutter/windows/runner/resources/app_icon.ico` as needed so title-bar matches taskbar
- Keep: `flutter/assets/IRANSansXFaNum-*.ttf` (add to git)

**Interfaces:**
- Produces: `MyTheme.accent` / primary aligned to `#0891B2` / `#0284C7`; app `fontFamily: 'IRANSansXFaNum'`; RTL when `Localizations.localeOf(context).languageCode == 'fa'`.

- [ ] **Step 1: Register fonts in pubspec**

Under `flutter: fonts:` add (Regular/Medium/Bold minimum; include other weights already on disk):

```yaml
    - family: IRANSansXFaNum
      fonts:
        - asset: assets/IRANSansXFaNum-Regular.ttf
        - asset: assets/IRANSansXFaNum-Medium.ttf
          weight: 500
        - asset: assets/IRANSansXFaNum-Bold.ttf
          weight: 700
```

- [ ] **Step 2: Retarget MyTheme accent/button colors**

In `flutter/lib/common.dart` `MyTheme`:

```dart
static const Color accent = Color(0xFF0891B2);
static const Color accent50 = Color(0x770891B2);
static const Color accent80 = Color(0xAA0891B2);
static const Color idColor = Color(0xFF0284C7);
static const Color button = Color(0xFF0284C7);
```

Update light/dark `ThemeData` `fontFamily` to `'IRANSansXFaNum'` wherever theme is built in `MyTheme`.

- [ ] **Step 3: Force RTL for Farsi**

Where `MaterialApp` / `GetMaterialApp` is constructed (desktop entry in `main.dart`), set:

```dart
builder: (context, child) {
  final lang = Localizations.localeOf(context).languageCode;
  final dir = lang == 'fa' ? TextDirection.rtl : TextDirection.ltr;
  return Directionality(textDirection: dir, child: child ?? const SizedBox.shrink());
},
```

Also set `locale` default to `fa` if not already (rebrand may have done this — verify, do not duplicate).

- [ ] **Step 4: Replace logo.png / app icons with Raatik mark**

Export `flutter/assets/logo.png` from `d:/Projects/RAATIK/RaatikRemote/raatik-logo.png`. Regenerate Windows `app_icon.ico` from the same source so the **window title-bar** icon matches the taskbar.

- [ ] **Step 5: Commit**

```bash
git add flutter/pubspec.yaml flutter/lib/common.dart flutter/lib/main.dart flutter/assets/ flutter/windows/runner/resources/ res/icon.png
git commit -m "$(cat <<'EOF'
feat(ui): Raatik theme, IRANSansXFaNum, RTL, and logo assets

EOF
)"
```

---

### Task 3: Force admin + API gate + remove server tip + brand string sweep

**Files:**
- Modify: `res/manifest.xml`
- Modify: `flutter/windows/runner/runner.exe.manifest`
- Create: `flutter/lib/raatik/flags.dart`
- Modify: call sites that show login / cloud address book (desktop home menu, settings tabs — search `Login`, `login.dart`, `address book`)
- Modify: `flutter/lib/desktop/pages/connection_page.dart` (remove `setup_server_tip` widget)
- Modify: `src/lang/fa.rs` — set `setup_server_tip` to `""`; fix remaining customer-visible `RustDesk` calques that substitution misses
- Modify: `src/lang/en.rs` — empty or neutralize `setup_server_tip` display path

**Interfaces:**
- Produces: `const bool kRaatikApiEnabled = false;`
- Consumes: existing translate keys; UI must not call tip widget when key empty **and** must not mount the tip row at all for RaatikDesk.

- [ ] **Step 1: Add trustInfo to both manifests**

Append inside `<assembly>` of `res/manifest.xml` and `runner.exe.manifest`:

```xml
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v3">
    <security>
      <requestedPrivileges>
        <requestedExecutionLevel level="requireAdministrator" uiAccess="false" />
      </requestedPrivileges>
    </security>
  </trustInfo>
```

- [ ] **Step 2: Create API flag**

Create `flutter/lib/raatik/flags.dart`:

```dart
/// When false, hide account login and cloud address-book UI.
/// Flip to true only after RAATIK ships an API — do not redesign those screens now.
const bool kRaatikApiEnabled = false;
```

- [ ] **Step 3: Gate API entry points**

Wrap every desktop entry that opens `login.dart` / cloud AB with `if (kRaatikApiEnabled) ...`. Do not delete the login widget file.

- [ ] **Step 4: Remove setup_server_tip from connection UI**

In `connection_page.dart`, delete or guard the widget that calls `translate('setup_server_tip')` so the banner never builds.

In `fa.rs` / `en.rs`:

```rust
("setup_server_tip", ""),
```

- [ ] **Step 5: Farsi brand leftover pass (high-visibility keys)**

Update customer-visible `fa.rs` values that still contain `RustDesk` awkwardly (install tips, About, scam tips, etc.) so either substitution yields RaatikDesk cleanly or the Farsi sentence is rewritten meaningfully. Do not touch `template.rs`.

- [ ] **Step 6: Commit**

```bash
git add res/manifest.xml flutter/windows/runner/runner.exe.manifest flutter/lib/raatik/flags.dart flutter/lib/desktop/pages/connection_page.dart flutter/lib/desktop/pages/desktop_home_page.dart flutter/lib/desktop/pages/desktop_setting_page.dart src/lang/fa.rs src/lang/en.rs
git commit -m "$(cat <<'EOF'
feat(ui): require admin, hide API UI, drop server-tip banner

EOF
)"
```

---

### Task 4: Home page B1 layout

**Files:**
- Modify: `flutter/lib/desktop/pages/desktop_home_page.dart`
- Modify: `flutter/lib/desktop/pages/connection_page.dart` (right/secondary connect column content)
- Modify: `src/lang/fa.rs` (+ `en.rs` if needed) for new label keys **or** reuse existing keys with rewritten Farsi values

**Interfaces:**
- Consumes: existing ID/password bind APIs already used on home (`bind.mainGet…` patterns in current home).
- Produces: RTL two-column UI — receive panel ~1.4fr, connect ~1fr.

- [ ] **Step 1: Sketch layout structure**

Replace the main body of desktop home with:

```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    Expanded(flex: 14, child: _ReceiveSupportPanel(...)), // dominant in RTL = start
    const SizedBox(width: 12),
    Expanded(flex: 10, child: _ConnectToPeerPanel(...)),
  ],
)
```

Under RTL `Directionality`, the first child appears on the right (dominant receive panel).

- [ ] **Step 2: Receive panel copy**

Use Farsi strings (via translate keys; add keys only if unavoidable — prefer rewriting existing keys):

- Title: آماده برای پشتیبانی اتوفای  
- Helper: شناسه این سیستم را برای پشتیبان بخوانید یا کپی کنید  
- شناسه من / رمز یک‌بارمصرف  
- CTA: کپی شناسه و رمز  

Wire copy buttons to existing clipboard helpers.

- [ ] **Step 3: Connect panel copy**

- Title: اتصال به سیستم دیگر  
- Helper: برای تیم پشتیبانی  
- ID field + اتصال using existing connect flow from `connection_page.dart`

- [ ] **Step 4: Manual / preview check**

Verify in preview harness (Task 7) or document checklist: receive larger; no server tip; logo Raatik.

- [ ] **Step 5: Commit**

```bash
git add flutter/lib/desktop/pages/desktop_home_page.dart flutter/lib/desktop/pages/connection_page.dart src/lang/fa.rs src/lang/en.rs
git commit -m "$(cat <<'EOF'
feat(ui): B1 RTL home — receive-dominant split layout

EOF
)"
```

---

### Task 5: Settings IA + meaningful Farsi subtitles

**Files:**
- Modify: `flutter/lib/desktop/pages/desktop_setting_page.dart` (sidebar labels, section order, hide API tabs)
- Modify: `src/lang/fa.rs` for settings titles/tooltips

**Interfaces:**
- Consumes: existing settings controllers / option keys — **do not rename option keys**, only labels and grouping UI.
- Produces: groups عمومی / برای پشتیبان / درباره per spec §7.

- [ ] **Step 1: Reorder / relabel sidebar entries**

Map existing pages into:

1. عمومی و ظاهر  
2. امنیت و دسترسی  
3. نمایش و کیفیت تصویر  
4. شبکه و سرور راتیک  
5. پیشرفته  
6. درباره RaatikDesk  

Hide any account/cloud entries when `!kRaatikApiEnabled`.

- [ ] **Step 2: Add Farsi help subtitles**

For opaque toggles, set translate values to `Title — short meaning` pattern, e.g. quality: explain clearer vs faster on weak internet. Keep UAC/2FA/TCP untranslated tokens.

- [ ] **Step 3: Commit**

```bash
git add flutter/lib/desktop/pages/desktop_setting_page.dart src/lang/fa.rs
git commit -m "$(cat <<'EOF'
feat(ui): customer-first settings IA and Farsi help copy

EOF
)"
```

---

### Task 6: Remote toolbar T1

**Files:**
- Modify: `flutter/lib/desktop/widgets/remote_toolbar.dart`
- Modify: `src/lang/fa.rs` for toolbar action labels

**Interfaces:**
- Consumes: existing toolbar action callbacks (file, chat, display, CAD, etc.).
- Produces: persistent top bar; overflow «بیشتر»; danger «پایان جلسه».

- [ ] **Step 1: Replace floating pin chrome with top AppBar-style bar**

Keep action handlers; change layout to a full-width top `Container`/`Material` bar with Primary background, actions in a `Row`, overflow `PopupMenuButton` labeled via translate('More') → «بیشتر».

- [ ] **Step 2: Relabel key actions in fa.rs**

Examples (adjust keys to match existing translate keys used by toolbar):

- File transfer → ارسال/دریافت فایل  
- Chat → گفتگو  
- Display → کنترل صفحه  
- Privacy mode → حریم خصوصی صفحه  
- Insert Ctrl+Alt+Del / OS → کنترل ویندوز  
- Disconnect / Close → پایان جلسه  

- [ ] **Step 3: Commit**

```bash
git add flutter/lib/desktop/widgets/remote_toolbar.dart src/lang/fa.rs
git commit -m "$(cat <<'EOF'
feat(ui): T1 persistent remote session top bar

EOF
)"
```

---

### Task 7: Flutter web preview harness

**Files:**
- Create: `flutter/lib/preview_main.dart`
- Create: `flutter/lib/preview/fake_home.dart` (static mock of B1)
- Create: `flutter/lib/preview/fake_settings.dart`
- Create: `flutter/lib/preview/fake_toolbar.dart`
- Optional doc note in spec or `flutter/README` snippet — keep minimal: comment at top of `preview_main.dart`

**Interfaces:**
- Produces: runnable UI without FFI. No `window_manager` init.

- [ ] **Step 1: Entrypoint**

```dart
import 'package:flutter/material.dart';
import 'preview/fake_home.dart';
import 'preview/fake_settings.dart';
import 'preview/fake_toolbar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RaatikPreviewApp());
}

class RaatikPreviewApp extends StatefulWidget {
  const RaatikPreviewApp({super.key});
  @override
  State<RaatikPreviewApp> createState() => _RaatikPreviewAppState();
}

class _RaatikPreviewAppState extends State<RaatikPreviewApp> {
  ThemeMode mode = ThemeMode.light;
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'IRANSansXFaNum',
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF0284C7),
          secondary: const Color(0xFF0891B2),
          surface: const Color(0xFFF8FAFC),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'IRANSansXFaNum',
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF38BDF8),
          secondary: const Color(0xFF22D3EE),
          surface: const Color(0xFF0F172A),
        ),
      ),
      locale: const Locale('fa'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('RaatikDesk Preview'),
          actions: [
            IconButton(
              tooltip: 'تم',
              onPressed: () => setState(() {
                mode = mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
              }),
              icon: const Icon(Icons.brightness_6),
            ),
          ],
        ),
        body: IndexedStack(
          index: tab,
          children: const [
            FakeHomePage(),
            FakeSettingsPage(),
            FakeToolbarPage(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'خانه'),
            NavigationDestination(icon: Icon(Icons.settings), label: 'تنظیمات'),
            NavigationDestination(icon: Icon(Icons.desktop_windows), label: 'نوار ریموت'),
          ],
        ),
      ),
    );
  }
}
```

Implement the three `Fake*` widgets as **static visual mocks** matching B1 / settings groups / T1 (hardcoded Farsi; no FFI).

- [ ] **Step 2: Run locally when Flutter SDK exists**

```bash
cd flutter
flutter pub get
flutter run -d chrome -t lib/preview_main.dart
```

Expected: Chrome opens RTL Farsi mock UI with IRANSans; no Rust build.

If Flutter SDK is missing on the machine, skip run; CI is not required to build preview.

- [ ] **Step 3: Commit**

```bash
git add flutter/lib/preview_main.dart flutter/lib/preview/
git commit -m "$(cat <<'EOF'
feat(ui): Chrome preview harness for RaatikDesk layouts

EOF
)"
```

---

### Task 8: Leak gate + CI verification

**Files:**
- Modify: `raatik/no_leak_gate.py` if new hardcoded English/RustDesk strings appear
- Trigger: `gh workflow run raatik-check --ref raatik/ui-2026.07.01`
- Trigger: `gh workflow run raatik-windows --ref raatik/ui-2026.07.01` when ready for artifact

**Interfaces:**
- Consumes: completed Tasks 1–7 on branch `raatik/ui-2026.07.01`.
- Produces: green check + `RaatikDesk-2026.07.01-install.exe` artifact.

- [ ] **Step 1: Run no_leak_gate locally**

```bash
python raatik/no_leak_gate.py
```

Expected: exit 0. If fail, fix allowlist only for true false-positives; never allow customer-visible RustDesk.

- [ ] **Step 2: Push branch and run check**

```bash
git push -u raatik HEAD
gh workflow run raatik-check --ref raatik/ui-2026.07.01
```

- [ ] **Step 3: Run windows release workflow**

```bash
gh workflow run raatik-windows --ref raatik/ui-2026.07.01
```

Download artifact; verify: UAC on start, title-bar Raatik logo, B1 home, no server tip, no login entry, Farsi RTL + font.

- [ ] **Step 4: Final commit only if gate tweaks needed**

```bash
git add raatik/no_leak_gate.py
git commit -m "$(cat <<'EOF'
test: align no-leak gate with UI redesign copy

EOF
)"
```

---

## Spec coverage checklist

| Spec section | Task(s) |
|---|---|
| §2 version / branch | 1 |
| §5 visual system (color, font, RTL, logo) | 2 |
| §9.2 admin | 3 |
| §4.2 / §9 API hide | 3 |
| §7 tip removal + brand leftovers | 3 |
| §6 Home B1 | 4 |
| §7 Settings IA + Farsi | 5 |
| §8 Toolbar T1 | 6 |
| §11 Preview harness | 7 |
| §13 Testing / CI | 8 |

## Self-review notes

- Semver `2026.7.1` vs display `2026.07.01` is intentional (Cargo/pub reject leading zeros).
- Login files remain in tree; only gated — matches “do not redesign API screens”.
- Preview mocks may drift from production widgets; prefer extracting shared presentational widgets later only if duplication hurts — YAGNI for v1.
