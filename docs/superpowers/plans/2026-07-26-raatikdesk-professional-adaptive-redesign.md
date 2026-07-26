# RaatikDesk Professional Adaptive Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Execute tasks in order and review after each task.

**Goal:** Replace the fixed, amateur Windows Flutter presentation with a professional Guided Support UI that adapts down to 800×600, makes the stopped-service action unmistakable, and guarantees the Raatik mark on every Windows icon surface.

**Architecture:** Preserve Rust, FFI, GetX/Provider models, option keys, and connection behavior. Add focused presentation-only modules under `flutter/lib/raatik/`; current desktop pages become thin adapters. Unify all Windows icons from canonical `res/icon.png` and `res/icon.ico`, then enforce consistency in CI.

**Tech stack:** Flutter 3.24.5, Dart, Material, GetX, Provider, Rust 1.75, Win32 resources, Python 3 standard library, GitHub Actions.

## Global constraints

- Scope: Windows window chrome, home, service states, settings, remote toolbar, dialogs, and icon pipeline.
- Out of scope: mobile platforms, protocol, relay, capture, input, and FFI contract changes.
- Visual direction: Guided Support—calm surfaces, clear next action, restrained depth.
- First launch follows Windows theme; users can override light/dark.
- Farsi uses IRANSansXFaNum and RTL; English uses LTR.
- Minimum supported size: 800×600.
- Below 900px: stack home panels and collapse settings navigation.
- Service stopped: show a critical gate above the home; dim and block remaining home controls.
- Keep the gate until `SvcStatus.ready`; never show optimistic success.
- `kRaatikApiEnabled` remains `false`.
- Practical interactive target size: at least 44×44 logical pixels.
- Preserve AGPL notices and upstream internal names required by code.
- Do not edit `src/lang/template.rs`.
- Do not create a worktree.

## Planned file structure

- `flutter/lib/raatik/theme/tokens.dart` — colors, spacing, radii, target sizes.
- `flutter/lib/raatik/theme/app_theme.dart` — light/dark theme builders.
- `flutter/lib/raatik/layout/breakpoints.dart` — compact/medium/wide classification.
- `flutter/lib/raatik/chrome/window_chrome.dart` — branded window header.
- `flutter/lib/raatik/home/service_gate.dart` — service phases and critical gate.
- `flutter/lib/raatik/home/home_layout.dart` — adaptive home composition.
- `flutter/lib/raatik/settings/settings_shell.dart` — adaptive grouped settings navigation.
- `flutter/lib/raatik/dialogs/dialog_style.dart` — shared dialog layout.
- `raatik/verify_windows_icons.py` — icon source/build gate.
- Focused tests under `flutter/test/` and `raatik/test_verify_windows_icons.py`.

---

### Task 1: Design tokens, themes, and breakpoints

**Files**

- Create `flutter/lib/raatik/theme/tokens.dart`
- Create `flutter/lib/raatik/theme/app_theme.dart`
- Create `flutter/lib/raatik/layout/breakpoints.dart`
- Modify `flutter/lib/common.dart` (`MyTheme`)
- Test `flutter/test/raatik_theme_test.dart`
- Test `flutter/test/raatik_breakpoints_test.dart`

**Interfaces**

- `RaatikWindowClass raatikWindowClassFor(double width)`
- `ThemeData buildRaatikLightTheme()`
- `ThemeData buildRaatikDarkTheme()`

- [ ] Write failing breakpoint tests for 800, 899.9, 900, 1199.9, and 1200.

```dart
expect(raatikWindowClassFor(800), RaatikWindowClass.compact);
expect(raatikWindowClassFor(900), RaatikWindowClass.medium);
expect(raatikWindowClassFor(1200), RaatikWindowClass.wide);
```

- [ ] Run `cd flutter; flutter test test/raatik_breakpoints_test.dart`.

Expected: import failure because the module does not exist.

- [ ] Add breakpoints.

```dart
enum RaatikWindowClass { compact, medium, wide }

RaatikWindowClass raatikWindowClassFor(double width) {
  if (width < 900) return RaatikWindowClass.compact;
  if (width < 1200) return RaatikWindowClass.medium;
  return RaatikWindowClass.wide;
}
```

- [ ] Add `RaatikTokens` with:

```dart
static const primary = Color(0xFF0284C7);
static const accent = Color(0xFF0891B2);
static const success = Color(0xFF059669);
static const danger = Color(0xFFDC2626);
static const lightCanvas = Color(0xFFF4F7FB);
static const darkCanvas = Color(0xFF111827);
static const minTarget = 44.0;
static const contentMaxWidth = 1440.0;
```

- [ ] Build Material themes using IRANSansXFaNum, Raatik colors, 12–16px radii, visible focus, and 44px buttons.
- [ ] Keep `ColorThemeExtension` and `TabbarTheme` attachment inside `MyTheme` to avoid circular imports.
- [ ] Replace only `MyTheme.lightTheme` and `MyTheme.darkTheme`; keep persistence methods unchanged.
- [ ] Run:

```powershell
cd flutter
dart format lib/raatik/theme lib/raatik/layout
flutter test test/raatik_theme_test.dart test/raatik_breakpoints_test.dart
```

- [ ] Commit: `feat(ui): add adaptive Raatik design foundation`

---

### Task 2: Professional Windows chrome

**Files**

- Create `flutter/lib/raatik/chrome/window_chrome.dart`
- Modify `flutter/lib/desktop/widgets/tabbar_widget.dart`
- Modify `flutter/lib/desktop/widgets/titlebar_widget.dart`
- Modify `flutter/lib/desktop/pages/desktop_tab_page.dart`
- Test `flutter/test/raatik_window_chrome_test.dart`

- [ ] Write a widget test requiring the Raatik logo, `RaatikDesk` title, and semantic label.
- [ ] Add `RaatikWindowBrand`.

```dart
class RaatikWindowBrand extends StatelessWidget {
  const RaatikWindowBrand({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'RaatikDesk',
        header: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo.png', width: 22, height: 22),
            const SizedBox(width: 8),
            const Text('RaatikDesk',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
```

- [ ] Replace legacy blue gradient/title fragments with flat theme surfaces and one-pixel dividers.
- [ ] Preserve drag, double-click maximize, minimize, restore, close, tabs, and resize behavior unchanged.
- [ ] Run `flutter test test/raatik_window_chrome_test.dart`.
- [ ] Commit: `feat(ui): add professional Raatik window chrome`

---

### Task 3: Critical service gate

**Files**

- Create `flutter/lib/raatik/home/service_gate.dart`
- Modify `flutter/lib/desktop/pages/desktop_home_page.dart`
- Modify `flutter/lib/desktop/pages/connection_page.dart`
- Test `flutter/test/raatik_service_gate_test.dart`

**Interfaces**

```dart
enum RaatikServicePhase { stopped, starting, connecting, ready, failed }

RaatikServicePhase deriveRaatikServicePhase({
  required bool stopped,
  required SvcStatus status,
  required bool startPending,
  required String? error,
});
```

- [ ] Write failing tests:
  - stopped wins over stale `SvcStatus.ready`;
  - «سرویس اجرا نشده» and «اجرای سرویس» are visible;
  - starting disables duplicate clicks and shows progress;
  - ready shows the compact success state;
  - failed shows retry.
- [ ] Implement phase mapping.
- [ ] Implement `RaatikServiceGate` as a live-region semantic container with:
  - danger border/background when stopped or failed;
  - full-width start/retry button;
  - spinner and disabled button while starting/connecting;
  - compact success row when ready.
- [ ] Pass copy through a `RaatikServiceGateCopy` value built from existing translation keys:

```dart
RaatikServiceGateCopy(
  stoppedTitle: translate('Service is not running'),
  startLabel: translate('Start service'),
  startingLabel: translate('connecting_status'),
  readyLabel: translate('Ready'),
  stoppedBody: translate('not_ready_status'),
  failedTitle: translate('Failed'),
  retryBody: translate('Retry'),
);
```

- [ ] In `_DesktopHomePageState`, add `_serviceStartPending`, `_serviceStartError`, and a 12-second timeout.
- [ ] Call existing `start_service(true)`.
- [ ] Clear the gate only after polling confirms `SvcStatus.ready`.
- [ ] Log technical errors with `debugPrint`; show translated customer copy.
- [ ] Remove the duplicate underlined low-visibility start link from `OnlineStatusWidget`.
- [ ] Cancel the timeout in `dispose()`.
- [ ] Run `flutter test test/raatik_service_gate_test.dart`.
- [ ] Commit: `feat(ui): make stopped service a critical guided action`

---

### Task 4: Adaptive home

**Files**

- Create `flutter/lib/raatik/home/home_layout.dart`
- Modify `flutter/lib/desktop/pages/desktop_home_page.dart`
- Modify `flutter/lib/desktop/pages/connection_page.dart`
- Test `flutter/test/raatik_home_layout_test.dart`

- [ ] Write tests at 800×600, 1024×600, 1366×768, and 1920×1080.
- [ ] Assert compact layout below 900px and two-column layout at 900px+.
- [ ] Add the production shell:

```dart
class RaatikHomeLayout extends StatelessWidget {
  const RaatikHomeLayout({
    super.key,
    required this.serviceGate,
    required this.receivePanel,
    required this.connectPanel,
    required this.blocked,
  });

  final Widget serviceGate;
  final Widget receivePanel;
  final Widget connectPanel;
  final bool blocked;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          final panels = compact
              ? Column(children: [
                  receivePanel,
                  const SizedBox(height: 12),
                  connectPanel,
                ])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 14, child: receivePanel),
                  const SizedBox(width: 12),
                  Expanded(flex: 10, child: connectPanel),
                ]);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              serviceGate,
              const SizedBox(height: 12),
              AbsorbPointer(
                absorbing: blocked,
                child: AnimatedOpacity(
                  opacity: blocked ? .48 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: panels,
                ),
              ),
            ],
          );
        },
      );
}
```

- [ ] Replace the fixed root `Row` in `DesktopHomePage` with this shell.
- [ ] Keep ID/password controllers, copy handlers, recent peers, and connection callbacks unchanged.
- [ ] Replace touched left/right padding with `EdgeInsetsDirectional`.
- [ ] Remove fixed panel heights that cause clipping or dead space.
- [ ] Run focused home and service tests.
- [ ] Commit: `feat(ui): make Raatik home adaptive down to 800px`

---

### Task 5: Adaptive settings

**Files**

- Create `flutter/lib/raatik/settings/settings_shell.dart`
- Modify `flutter/lib/desktop/pages/desktop_setting_page.dart`
- Test `flutter/test/raatik_settings_shell_test.dart`

**Interfaces**

```dart
class RaatikSettingsDestination<T> {
  const RaatikSettingsDestination({
    required this.keyValue,
    required this.label,
    required this.group,
    required this.icon,
  });
  final T keyValue;
  final String label;
  final String group;
  final IconData icon;
}
```

- [ ] Write tests:
  - 800px uses compact dropdown/header;
  - 900px+ uses grouped sidebar;
  - selecting either navigation mode invokes the same callback;
  - no horizontal overflow.
- [ ] Build `RaatikSettingsShell<T>` using `LayoutBuilder`.
- [ ] Use a compact 56px dropdown header below 900px.
- [ ] Use a 232px grouped sidebar at 900px+.
- [ ] Group destinations:
  - عمومی: general, safety
  - برای پشتیبان: display, network, plugin, printer
  - حساب: account only when `kRaatikApiEnabled`
  - درباره: about
- [ ] Keep `SettingsTabKey`, current `PageController`, conditions, and setting bodies.
- [ ] Remove `_kCardFixedWidth = 540`; use `BoxConstraints(maxWidth: 900)` and full available width.
- [ ] Add short explanatory subtitles to technical settings using existing translation infrastructure.
- [ ] Run `flutter test test/raatik_settings_shell_test.dart`.
- [ ] Commit: `feat(ui): add responsive grouped settings shell`

---

### Task 6: Remote toolbar and dialogs

**Files**

- Create `flutter/lib/raatik/dialogs/dialog_style.dart`
- Modify `flutter/lib/desktop/widgets/remote_toolbar.dart`
- Modify `flutter/lib/common.dart` (`CustomAlertDialog`, `dialogButton`)
- Test `flutter/test/raatik_toolbar_dialog_test.dart`

- [ ] Write tests for 44px actions, visible focus, semantic labels, and 800px toolbar overflow.
- [ ] Add dialog constants:

```dart
abstract final class RaatikDialogStyle {
  static const maxWidth = 560.0;
  static const padding = EdgeInsets.all(24);
}
```

- [ ] Constrain desktop dialogs to 560px while preserving mobile behavior.
- [ ] Use wrapping dialog actions so translated labels do not clip.
- [ ] Keep the remote toolbar full-width and persistent.
- [ ] Below 900px, show icon-first critical controls and keep «بیشتر» plus «پایان جلسه» outside horizontal scrolling.
- [ ] At 900px+, show RaatikDesk and peer label.
- [ ] Keep all existing action handlers and permission conditions unchanged.
- [ ] Danger-style disconnect/end-session action.
- [ ] Run `flutter test test/raatik_toolbar_dialog_test.dart`.
- [ ] Commit: `feat(ui): polish responsive toolbar and dialogs`

---

### Task 7: Single-source Raatik Windows icons

**Files**

- Create `flutter/assets/icon.png`
- Create `flutter/assets/icon.ico`
- Replace `res/tray-icon.ico`
- Replace `flutter/windows/runner/resources/app_icon.ico`
- Verify/replace `flutter/assets/icon.svg`
- Create `raatik/verify_windows_icons.py`
- Create `raatik/test_verify_windows_icons.py`
- Modify `.github/workflows/raatik-check.yml`
- Modify `.github/workflows/raatik-windows.yml`

- [ ] Write failing Python tests for missing and mismatched icons.
- [ ] Synchronize canonical assets:

```powershell
Copy-Item -Force "res\icon.ico" "res\tray-icon.ico"
Copy-Item -Force "res\icon.ico" "flutter\windows\runner\resources\app_icon.ico"
Copy-Item -Force "res\icon.ico" "flutter\assets\icon.ico"
Copy-Item -Force "res\icon.png" "flutter\assets\icon.png"
Copy-Item -Force "res\logo.svg" "flutter\assets\icon.svg"
```

- [ ] Implement a standard-library SHA-256 gate:

```python
def check_icon_sources(root: Path) -> list[str]:
    groups = {
        "res/icon.ico": (
            "res/tray-icon.ico",
            "flutter/windows/runner/resources/app_icon.ico",
            "flutter/assets/icon.ico",
        ),
        "res/icon.png": ("flutter/assets/icon.png",),
    }
    errors = []
    for canonical, candidates in groups.items():
        source = root / canonical
        expected = hashlib.sha256(source.read_bytes()).hexdigest()
        for relative in candidates:
            candidate = root / relative
            if not candidate.is_file():
                errors.append(f"missing icon: {relative}")
            elif hashlib.sha256(candidate.read_bytes()).hexdigest() != expected:
                errors.append(f"icon differs from {canonical}: {relative}")
    return errors
```

- [ ] Add release-output checks for:
  - `Release/data/flutter_assets/assets/icon.ico`
  - `Release/data/flutter_assets/assets/icon.png`
- [ ] Run:

```powershell
python -m unittest raatik/test_verify_windows_icons.py -v
python raatik/verify_windows_icons.py
```

- [ ] Add source icon gate to `raatik-check.yml`.
- [ ] Add post-build runtime icon gate to `raatik-windows.yml`.
- [ ] Confirm `Runner.rc` still embeds `resources\app_icon.ico`.
- [ ] Confirm portable wrapper still embeds `res/icon.ico`.
- [ ] If MSI is shipped, pass `--app-name RaatikDesk` and confirm copied MSI icon matches canonical ICO.
- [ ] Commit: `fix(windows): unify every app icon on the Raatik mark`

---

### Task 8: Production-component preview and responsive matrix

**Files**

- Modify `flutter/lib/preview_main.dart`
- Modify `flutter/lib/preview/fake_home.dart`
- Modify `flutter/lib/preview/fake_settings.dart`
- Modify `flutter/lib/preview/fake_toolbar.dart`
- Create `flutter/test/raatik_responsive_matrix_test.dart`

- [ ] Replace duplicate preview styling with production presentation widgets.
- [ ] Keep only fake values and callbacks in preview files.
- [ ] Add preview controls for theme, locale, and all service phases.
- [ ] Test 800×600, 1024×600, 1366×768, and 1920×1080.
- [ ] Test Farsi RTL and English LTR.
- [ ] Test light/dark/system modes.
- [ ] Assert `tester.takeException()` is null at every size.
- [ ] Run:

```powershell
cd flutter
dart format lib/raatik lib/preview lib/preview_main.dart test
flutter analyze lib/raatik lib/preview lib/preview_main.dart
flutter test
flutter run -d chrome -t lib/preview_main.dart
```

- [ ] Commit: `test(ui): preview production widgets across responsive states`

---

### Task 9: Windows artifact acceptance

- [ ] Run local checks:

```powershell
cd flutter
dart format --output=none --set-exit-if-changed lib/raatik lib/preview lib/preview_main.dart test
flutter analyze lib/raatik lib/preview lib/preview_main.dart
flutter test
cd ..
python -m unittest raatik/test_verify_windows_icons.py -v
python raatik/verify_windows_icons.py
```

- [ ] Trigger `raatik-check` and require success.
- [ ] Trigger `raatik-windows` and require success.
- [ ] Download `raatikdesk-windows-x86_64`.
- [ ] Extract the installer icon:

```powershell
$installer = Resolve-Path "RaatikDesk-2026.07.01-install.exe"
Add-Type -AssemblyName System.Drawing
$icon = [System.Drawing.Icon]::ExtractAssociatedIcon($installer.Path)
$icon.ToBitmap().Save("$env:TEMP\raatikdesk-installer-icon.png")
Start-Process "$env:TEMP\raatikdesk-installer-icon.png"
```

- [ ] Confirm Raatik icon on installer, EXE, title bar, taskbar, tray, desktop shortcut, Start shortcut, and Apps & Features.
- [ ] If Windows shows stale cache, run `ie4uinit.exe -show`, unpin the old shortcut, and relaunch. Confirm extracted binary icon remains Raatik.
- [ ] Verify all target sizes at 100%, 125%, and 150% scaling.
- [ ] Verify stopped → starting → ready and failed → retry flows.
- [ ] Verify remote toolbar and representative dialogs at 800×600.
- [ ] Add CI URLs and acceptance results to the PR description.
- [ ] Do not create an empty verification commit.

## Requirement coverage

- Guided Support design system: Task 1
- System theme and RTL/LTR: Tasks 1 and 8
- Professional window chrome: Task 2
- Visible service warning/action: Task 3
- Responsive home: Task 4
- Responsive settings: Task 5
- Toolbar/dialog consistency: Task 6
- Raatik Windows icons: Tasks 7 and 9
- Final artifact verification: Task 9

## Self-review

- No design spec is created.
- Rust/FFI/model contracts remain unchanged.
- Only backend `SvcStatus.ready` clears the service gate.
- Runtime and tray icon paths are covered, not only the already-correct runner ICO.
- Preview uses production presentation widgets to prevent drift.
- Every task has focused tests and a reviewable commit boundary.
