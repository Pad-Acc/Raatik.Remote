# RaatikDesk Redesign, Plan 1: Numbers in RTL and Design-System Foundations

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Load the `raatik-desk-design` skill before every task.

**Goal:** Make every number in RaatikDesk render and accept input correctly in a Persian RTL UI (Latin digits, LTR islands, Persian-digit normalisation, copy-safe), and land the token, breakpoint and text-style foundations that the later redesign plans build on.

**Architecture:** A small pure-Dart layer under `flutter/lib/raatik/` (tokens, text styles, digit normalisation, two identifier widgets) is added with unit and widget tests, then wired into the existing call sites: the ID formatter, the home ID and password boards, the remote-ID field, the autocomplete rows, the peer card, the numeric dialog fields and the preview harness. No Rust, FFI or translation-key changes. Visual redesign of the home window, peer tiles, session toolbar, dialogs and settings is deferred to Plans 2 to 5 (roadmap at the end).

**Tech Stack:** Flutter (CI pins 3.22.3, `useMaterial3: false`), Dart, `flutter_test`, GetX (`Obx`, `.obs`), the existing `flutter_hbb` package. Tests run from `rustdesk/flutter` with `fvm flutter test test/<file>`.

**Spec:** `rustdesk/raatik/design/DESIGN-SYSTEM.md` (sections 1.2 to 1.6, 1.11, 4 and 5) and `rustdesk/raatik/design/SCREENS.md` section 6. The agent skill is `.claude/skills/raatik-desk-design/SKILL.md`.

## Global Constraints

- Toolchain: Flutter **3.22.3** through FVM (`fvm flutter ...`), pinned in Task 0. The machine's global Flutter is 3.44.8 and cannot compile `app_theme.dart` (`DialogTheme` / `TabBarTheme` were renamed after 3.22), so every `flutter` command in this plan is written as `fvm flutter`. CI (`raatik-check.yml`) pins the same 3.22.3.
- Write code that compiles on 3.22.3: use `MaterialStatePropertyAll`, `DialogTheme`, `TabBarTheme`; do not use `WidgetState*`, `DialogThemeData` or `TabBarThemeData`.
- `flutter/pubspec.yaml` and `flutter/pubspec.lock` are never committed by this plan. The local `extended_text` downgrade in Task 0 mirrors CI and is reverted before each commit.
- Only directional layout APIs (`EdgeInsetsDirectional`, `AlignmentDirectional`, `start`/`end`). `TextDirection.ltr` appears only inside `ltrTextDirection()` around identifier widgets.
- Spacing values only from 4, 8, 12, 16, 20, 24, 32. Radii only 8, 12, 16, 20, pill.
- Identifier style font: `fontFamily: 'Segoe UI'`, fallbacks `['Roboto', 'Helvetica Neue', 'Arial']`, `FontFeature.tabularFigures()`. Mono: `'Consolas'`, fallbacks `['Menlo', 'monospace']`.
- Breakpoints: compact `< 640`, medium `640 to 1199.9`, wide `>= 1200`.
- Isolate characters (U+2066, U+2069) never enter a `TextEditingController`; they are added only in `Text` widgets via `ltrIsolate()`.
- `IDTextEditingController.id` keeps returning raw digits via `trimID`.
- No Persian string literals in Dart outside `lib/preview/`. No new keys in `src/lang/*.rs` in this plan.
- Every new file under `lib/raatik/` gets a test under `test/` named `raatik_<topic>_test.dart`.
- Work on a branch created from `raatik/ui-2026.08.01`, for example `raatik/ui-numbers-rtl`. Commit after each task. End every commit message with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.

## Review Focus

1. A user on a Persian keyboard layout types `۱۰۷۲۹۲۳۴۷` into the remote-ID field and expects `107 292 347`; today the field shows Persian digits and `int.tryParse` fails, so no grouping and no connect. Pinned in Task 3 and Task 5.
2. A user pastes `107-292-347`, `107 292 347` followed by a newline, or an ID copied from a chat app that carries U+2066/U+2069; they expect `107 292 347`. Pinned in Task 3.
3. A user types a direct address such as `192.168.1.5:21118` or `my-host.local`, or an ID with the relay suffix `123456789/r`; these must pass through unchanged. Pinned in Task 3.
4. A user copies their own ID from the home card and pastes it into a message; they expect `231339258` with no spaces and no invisible characters. Pinned in Task 3 (`identifierClipboardText`) and used in Task 6.
5. A user enters a 2FA code or a port on a Persian keyboard; today `FilteringTextInputFormatter.allow([0-9])` silently drops every keystroke. Pinned in Task 4.

---

### Task 0: Baseline and toolchain pin

**Files:**
- Modify: `flutter/.gitignore` (add `.fvm/`)

- [ ] **Step 1: Create the working branch**

```bash
cd D:/Projects/RAATIK/RaatikRemote/rustdesk
git checkout raatik/ui-2026.08.01
git checkout -b raatik/ui-numbers-rtl
```

- [ ] **Step 2: Install FVM and pin Flutter 3.22.3 for the flutter/ project**

FVM keeps 3.22.3 in its own cache and leaves the global `D:\flutter` (3.44.8) untouched.

```bash
dart pub global activate fvm
export PATH="$PATH:$USERPROFILE/AppData/Local/Pub/Cache/bin"
cd flutter
fvm install 3.22.3
fvm use 3.22.3 --force
fvm flutter --version
```

Expected: the last line reports `Flutter 3.22.3`. Then add the FVM folder to the project ignore list:

```bash
grep -qx '.fvm/' .gitignore || printf '\n# FVM local SDK link\n.fvm/\n' >> .gitignore
```

- [ ] **Step 3: Resolve packages the way CI does**

Flutter 3.22.3 ships a Dart too old for `extended_text: 14.0.0`; CI downgrades it before `pub get` (`raatik-check.yml` line 108). Do the same locally and keep the change out of git:

```bash
sed -i -e 's/extended_text: 14.0.0/extended_text: 13.0.0/g' pubspec.yaml
fvm flutter pub get
git update-index --skip-worktree pubspec.yaml pubspec.lock
```

`--skip-worktree` makes git ignore the local edits so they cannot slip into a commit. To undo at the end of the plan: `git update-index --no-skip-worktree pubspec.yaml pubspec.lock && git checkout pubspec.yaml pubspec.lock`.

- [ ] **Step 4: Run the existing RAATIK test files and record the baseline**

```bash
fvm flutter test test/raatik_bidi_test.dart test/raatik_breakpoints_test.dart test/raatik_home_layout_test.dart test/raatik_settings_shell_test.dart test/raatik_responsive_matrix_test.dart test/raatik_rtl_home_test.dart test/raatik_theme_test.dart
```

Expected: all pass. (Under the global 3.44.8 SDK these files fail to *load* with `DialogTheme can't be assigned to DialogThemeData?`; that is the toolchain mismatch, not a product bug. If the same error appears under `fvm flutter`, the pin did not take: re-run `fvm use 3.22.3 --force` and check `fvm flutter --version`.) If a different test fails on the untouched branch, paste its name and message into the task report and continue; do not fix it inside this plan unless a later task touches that file.

- [ ] **Step 5: Commit the ignore entry**

```bash
cd ..
git add flutter/.gitignore
git commit -m "chore(flutter): ignore the FVM SDK link folder

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 1: Tokens and breakpoints

**Files:**
- Modify: `flutter/lib/raatik/theme/tokens.dart`
- Modify: `flutter/lib/raatik/layout/breakpoints.dart`
- Modify: `flutter/lib/raatik/home/home_layout.dart:22`
- Modify: `flutter/lib/raatik/settings/settings_shell.dart:41`
- Modify: `flutter/test/raatik_breakpoints_test.dart`
- Modify: `flutter/test/raatik_home_layout_test.dart:76,118`
- Create: `flutter/test/raatik_tokens_test.dart`

**Interfaces:**
- Produces: `RaatikTokens.space1..space8`, `radiusXs/Sm/Lg/Xl/Pill`, `minTarget`, `heroInput`, `toolbarBtn`, `toolbarBar`, `rail`, `sidebar`, `heroMax`, `dialogMax`, `confirmDialogMax`, `tileMaxExtent`, `tileHeader`, `tileFooter`, `iconSm/Md/Lg`, `glyph`, `dot`, `compactMax`, `mediumMax`, `motion`, `curve`, `numericField4`, `numericField5`. Existing names (`spaceXs..spaceXl`, `radiusSm`, `radiusLg`, `iconLabelGap`, `inputContentPadding`, colours) keep their values.

- [ ] **Step 1: Write the failing tests**

Replace the body of `flutter/test/raatik_breakpoints_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/raatik/layout/breakpoints.dart';
import 'package:flutter_hbb/raatik/theme/tokens.dart';

void main() {
  test('classifies window widths into compact, medium, and wide', () {
    expect(raatikWindowClassFor(480), RaatikWindowClass.compact);
    expect(raatikWindowClassFor(639.9), RaatikWindowClass.compact);
    expect(raatikWindowClassFor(640), RaatikWindowClass.medium);
    expect(raatikWindowClassFor(1199.9), RaatikWindowClass.medium);
    expect(raatikWindowClassFor(1200), RaatikWindowClass.wide);
  });

  test('breakpoints come from tokens', () {
    expect(RaatikTokens.compactMax, 640);
    expect(RaatikTokens.mediumMax, 1200);
  });
}
```

Create `flutter/test/raatik_tokens_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/raatik/theme/tokens.dart';

void main() {
  test('spacing scale is 4-based and legacy names alias it', () {
    expect([
      RaatikTokens.space1,
      RaatikTokens.space2,
      RaatikTokens.space3,
      RaatikTokens.space4,
      RaatikTokens.space5,
      RaatikTokens.space6,
      RaatikTokens.space8,
    ], [4, 8, 12, 16, 20, 24, 32]);
    expect(RaatikTokens.spaceXs, RaatikTokens.space1);
    expect(RaatikTokens.spaceSm, RaatikTokens.space2);
    expect(RaatikTokens.spaceMd, RaatikTokens.space3);
    expect(RaatikTokens.spaceLg, RaatikTokens.space4);
    expect(RaatikTokens.spaceXl, RaatikTokens.space5);
  });

  test('radius scale steps 8 12 16 20 pill', () {
    expect([
      RaatikTokens.radiusXs,
      RaatikTokens.radiusSm,
      RaatikTokens.radiusLg,
      RaatikTokens.radiusXl,
    ], [8, 12, 16, 20]);
    expect(RaatikTokens.radiusPill, greaterThanOrEqualTo(999));
  });

  test('control sizes match the design system', () {
    expect(RaatikTokens.minTarget, 44);
    expect(RaatikTokens.heroInput, 52);
    expect(RaatikTokens.toolbarBtn, 36);
    expect(RaatikTokens.toolbarBar, 48);
    expect(RaatikTokens.rail, 64);
    expect(RaatikTokens.sidebar, 232);
    expect(RaatikTokens.heroMax, 640);
    expect(RaatikTokens.tileMaxExtent, 220);
    expect(RaatikTokens.tileHeader + RaatikTokens.tileFooter, 136);
    expect(RaatikTokens.numericField4, 64);
    expect(RaatikTokens.numericField5, 80);
    expect(RaatikTokens.motion, const Duration(milliseconds: 180));
    expect(RaatikTokens.curve, Curves.easeOutCubic);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `fvm flutter test test/raatik_breakpoints_test.dart test/raatik_tokens_test.dart`
Expected: compile errors, `compactMax`, `space1`, `radiusXs` not defined.

- [ ] **Step 3: Rewrite tokens.dart**

Replace the whole file `flutter/lib/raatik/theme/tokens.dart`:

```dart
import 'package:flutter/material.dart';

/// RaatikDesk design tokens. See raatik/design/DESIGN-SYSTEM.md sections 1 and 4.
class RaatikTokens {
  RaatikTokens._();

  // Colour: RaatikDesk palette (deliberately not taken from any reference app).
  static const primary = Color(0xFF0284C7);
  static const accent = Color(0xFF0891B2);
  static const success = Color(0xFF059669);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const lightCanvas = Color(0xFFF4F7FB);
  static const darkCanvas = Color(0xFF111827);

  // Spacing: 4-based scale.
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 20.0;
  static const space6 = 24.0;
  static const space8 = 32.0;
  // Legacy aliases kept for existing call sites.
  static const spaceXs = space1;
  static const spaceSm = space2;
  static const spaceMd = space3;
  static const spaceLg = space4;
  static const spaceXl = space5;
  static const iconLabelGap = space3;

  // Radius: nested containers step 20 -> 16 -> 12 -> 8.
  static const radiusXs = 8.0;
  static const radiusSm = 12.0;
  static const radiusLg = 16.0;
  static const radiusXl = 20.0;
  static const radiusPill = 999.0;

  // Sizes.
  static const minTarget = 44.0;
  static const heroInput = 52.0;
  static const toolbarBtn = 36.0;
  static const toolbarBar = 48.0;
  static const rail = 64.0;
  static const sidebar = 232.0;
  static const heroMax = 640.0;
  static const dialogMax = 560.0;
  static const confirmDialogMax = 360.0;
  static const tileMaxExtent = 220.0;
  static const tileHeader = 96.0;
  static const tileFooter = 40.0;
  static const iconSm = 16.0;
  static const iconMd = 20.0;
  static const iconLg = 24.0;
  static const glyph = 48.0;
  static const dot = 8.0;
  static const contentMaxWidth = 1440.0;
  /// Widths for short numeric fields (ports, resolutions, codes).
  static const numericField4 = 64.0;
  static const numericField5 = 80.0;

  // Breakpoints (window width). compact < compactMax <= medium < mediumMax <= wide.
  static const compactMax = 640.0;
  static const mediumMax = 1200.0;

  // Motion.
  static const motion = Duration(milliseconds: 180);
  static const curve = Curves.easeOutCubic;

  static const inputContentPadding =
      EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12);
}
```

- [ ] **Step 4: Point breakpoints, home layout and settings shell at the tokens**

Replace `flutter/lib/raatik/layout/breakpoints.dart`:

```dart
import '../theme/tokens.dart';

enum RaatikWindowClass { compact, medium, wide }

RaatikWindowClass raatikWindowClassFor(double width) {
  if (width < RaatikTokens.compactMax) return RaatikWindowClass.compact;
  if (width < RaatikTokens.mediumMax) return RaatikWindowClass.medium;
  return RaatikWindowClass.wide;
}
```

In `flutter/lib/raatik/home/home_layout.dart` add `import '../theme/tokens.dart';` and change line 22 to:

```dart
          final compact = constraints.maxWidth < RaatikTokens.compactMax;
```

In `flutter/lib/raatik/settings/settings_shell.dart` change line 41 to:

```dart
  static const compactBreakpoint = RaatikTokens.compactMax;
```

(`tokens.dart` is already imported there.)

- [ ] **Step 5: Update the two home-layout tests that assumed compact at 800**

In `flutter/test/raatik_home_layout_test.dart` line 75 to 76 change the test name and width to `600x600 uses compact stacked layout` / `_pumpHome(tester, 600, 600)`, and line 117 to 118 to `omits connect panel in compact layout at 600` / `_pumpHome(tester, 600, 600, showConnectPanel: false)`.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `fvm flutter test test/raatik_breakpoints_test.dart test/raatik_tokens_test.dart test/raatik_home_layout_test.dart test/raatik_settings_shell_test.dart test/raatik_responsive_matrix_test.dart`
Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add flutter/lib/raatik/theme/tokens.dart flutter/lib/raatik/layout/breakpoints.dart flutter/lib/raatik/home/home_layout.dart flutter/lib/raatik/settings/settings_shell.dart flutter/test/raatik_breakpoints_test.dart flutter/test/raatik_tokens_test.dart flutter/test/raatik_home_layout_test.dart
git commit -m "feat(raatik): extend design tokens and move breakpoints to 640/1200

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: Text styles with a Latin-digit identifier face

**Files:**
- Create: `flutter/lib/raatik/theme/text_styles.dart`
- Create: `flutter/test/raatik_text_styles_test.dart`

**Interfaces:**
- Produces: `RaatikTextStyles.identifier(BuildContext, {double? fontSize, FontWeight? fontWeight, Color? color})`, `displayId(context)`, `mono(context)`, `titleLg(context)`, `titleMd(context)`, `body(context)`, `label(context)`, `caption(context)`; constants `kRaatikIdentifierFontFamily`, `kRaatikIdentifierFontFallback`, `kRaatikMonoFontFamily`, `kRaatikMonoFontFallback`.

- [ ] **Step 1: Write the failing test**

Create `flutter/test/raatik_text_styles_test.dart`:

```dart
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/raatik/theme/app_theme.dart';
import 'package:flutter_hbb/raatik/theme/text_styles.dart';

Future<BuildContext> _contextWith(WidgetTester tester, ThemeData theme) async {
  late BuildContext captured;
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: Builder(builder: (context) {
      captured = context;
      return const SizedBox.shrink();
    }),
  ));
  return captured;
}

void main() {
  testWidgets('identifier uses a Latin-digit face with tabular figures',
      (tester) async {
    final context = await _contextWith(tester, buildRaatikLightTheme());
    final style = RaatikTextStyles.identifier(context);
    expect(style.fontFamily, kRaatikIdentifierFontFamily);
    expect(style.fontFamily, isNot('IRANSansXFaNum'));
    expect(style.fontFamilyFallback, kRaatikIdentifierFontFallback);
    expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(style.fontSize, 14);
    expect(style.fontWeight, FontWeight.w500);
  });

  testWidgets('displayId is 26/500 with 1.5 letter spacing', (tester) async {
    final context = await _contextWith(tester, buildRaatikDarkTheme());
    final style = RaatikTextStyles.displayId(context);
    expect(style.fontSize, 26);
    expect(style.fontWeight, FontWeight.w500);
    expect(style.letterSpacing, 1.5);
    expect(style.height, 1.2);
    expect(style.fontFamily, kRaatikIdentifierFontFamily);
  });

  testWidgets('prose styles keep the theme (FaNum) font', (tester) async {
    final context = await _contextWith(tester, buildRaatikLightTheme());
    expect(RaatikTextStyles.titleLg(context).fontSize, 18);
    expect(RaatikTextStyles.titleLg(context).fontWeight, FontWeight.w700);
    expect(RaatikTextStyles.titleMd(context).fontSize, 16);
    expect(RaatikTextStyles.body(context).fontSize, 14);
    expect(RaatikTextStyles.body(context).height, 1.6);
    expect(RaatikTextStyles.label(context).fontSize, 13);
    expect(RaatikTextStyles.caption(context).fontSize, 12);
    // No explicit family: inherits IRANSansXFaNum from ThemeData.fontFamily.
    expect(RaatikTextStyles.body(context).fontFamily, isNull);
  });

  testWidgets('mono uses the mono family', (tester) async {
    final context = await _contextWith(tester, buildRaatikLightTheme());
    expect(RaatikTextStyles.mono(context).fontFamily, kRaatikMonoFontFamily);
    expect(RaatikTextStyles.mono(context).fontFeatures,
        contains(const FontFeature.tabularFigures()));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `fvm flutter test test/raatik_text_styles_test.dart`
Expected: compile error, `text_styles.dart` does not exist.

- [ ] **Step 3: Implement text_styles.dart**

Create `flutter/lib/raatik/theme/text_styles.dart`:

```dart
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// Latin-digit faces. An explicit [TextStyle.fontFamily] overrides the
/// theme's IRANSansXFaNum, whose ASCII digits render as Persian numerals.
const String kRaatikIdentifierFontFamily = 'Segoe UI';
const List<String> kRaatikIdentifierFontFallback = [
  'Roboto',
  'Helvetica Neue',
  'Arial',
];
const String kRaatikMonoFontFamily = 'Consolas';
const List<String> kRaatikMonoFontFallback = ['Menlo', 'monospace'];

/// Text styles from DESIGN-SYSTEM.md section 1.6. Prose styles inherit the
/// theme font; identifier and mono force a Latin-digit face.
class RaatikTextStyles {
  RaatikTextStyles._();

  static TextStyle _base(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium ?? const TextStyle();

  static Color? _strong(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge?.color;

  /// IDs, passwords, versions, IPs, durations, shortcuts, monitor numbers.
  static TextStyle identifier(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) =>
      _base(context).copyWith(
        fontFamily: kRaatikIdentifierFontFamily,
        fontFamilyFallback: kRaatikIdentifierFontFallback,
        fontFeatures: const [FontFeature.tabularFigures()],
        fontSize: fontSize ?? 14,
        fontWeight: fontWeight ?? FontWeight.w500,
        height: 1.4,
        color: color ?? _strong(context),
      );

  /// The remote-ID field value and the user's own ID in the hero.
  static TextStyle displayId(BuildContext context) =>
      identifier(context, fontSize: 26, fontWeight: FontWeight.w500)
          .copyWith(height: 1.2, letterSpacing: 1.5);

  /// IPs, ports, keys, logs.
  static TextStyle mono(BuildContext context) => _base(context).copyWith(
        fontFamily: kRaatikMonoFontFamily,
        fontFamilyFallback: kRaatikMonoFontFallback,
        fontFeatures: const [FontFeature.tabularFigures()],
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: _strong(context),
      );

  static TextStyle titleLg(BuildContext context) => _base(context).copyWith(
      fontSize: 18, fontWeight: FontWeight.w700, height: 1.4, color: _strong(context));

  static TextStyle titleMd(BuildContext context) => _base(context).copyWith(
      fontSize: 16, fontWeight: FontWeight.w600, height: 1.4, color: _strong(context));

  static TextStyle body(BuildContext context) =>
      _base(context).copyWith(fontSize: 14, fontWeight: FontWeight.w400, height: 1.6);

  static TextStyle label(BuildContext context) =>
      _base(context).copyWith(fontSize: 13, fontWeight: FontWeight.w500, height: 1.4);

  static TextStyle caption(BuildContext context) => _base(context).copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: Theme.of(context).textTheme.bodySmall?.color);
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `fvm flutter test test/raatik_text_styles_test.dart`
Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add flutter/lib/raatik/theme/text_styles.dart flutter/test/raatik_text_styles_test.dart
git commit -m "feat(raatik): add text styles with a Latin-digit identifier face

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: Digit normalisation and a normalising ID formatter

**Files:**
- Create: `flutter/lib/raatik/text/digits.dart`
- Modify: `flutter/lib/common/formatter/id_formatter.dart`
- Create: `flutter/test/raatik_digits_test.dart`

**Interfaces:**
- Produces in `digits.dart`: `String normalizeDigits(String)`, `String stripBidiControls(String)`, `String normalizeIdentifierInput(String)`.
- Produces in `id_formatter.dart`: `String identifierClipboardText(String)`; `IDTextInputFormatter` and `IDTextEditingController.id=` now normalise before grouping. `formatID`, `trimID`, `formatIDForDisplay` unchanged.

- [ ] **Step 1: Write the failing tests**

Create `flutter/test/raatik_digits_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/raatik/text/digits.dart';

void main() {
  group('normalizeDigits', () {
    test('maps Persian digits to ASCII', () {
      expect(normalizeDigits('۱۰۷۲۹۲۳۴۷'), '107292347');
    });
    test('maps Arabic-Indic digits to ASCII', () {
      expect(normalizeDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
    });
    test('leaves letters and ASCII digits alone', () {
      expect(normalizeDigits('host-12.local:21118'), 'host-12.local:21118');
      expect(normalizeDigits(''), '');
    });
  });

  group('stripBidiControls', () {
    test('removes isolates, embeddings and marks', () {
      expect(stripBidiControls('\u2066107 292 347\u2069'), '107 292 347');
      expect(stripBidiControls('\u202Aabc\u202C\u200E\u200F\u061C'), 'abc');
    });
  });

  group('normalizeIdentifierInput', () {
    test('strips hyphens and spaces when the rest is a numeric ID', () {
      expect(normalizeIdentifierInput('107-292-347'), '107292347');
      expect(normalizeIdentifierInput('107 292 347\n'), '107292347');
      expect(normalizeIdentifierInput('\u2066107\u00A0292\u202F347\u2069'),
          '107292347');
    });
    test('normalises Persian digits', () {
      expect(normalizeIdentifierInput('۱۰۷ ۲۹۲ ۳۴۷'), '107292347');
    });
    test('keeps the relay suffix', () {
      expect(normalizeIdentifierInput('123 456 789/r'), '123456789/r');
      expect(normalizeIdentifierInput(r'123456789\r'), r'123456789\r');
    });
    test('passes hostnames and ip:port through untouched', () {
      expect(normalizeIdentifierInput('192.168.1.5:21118'), '192.168.1.5:21118');
      expect(normalizeIdentifierInput('my-host.local'), 'my-host.local');
      expect(normalizeIdentifierInput('remote.raatik.ir'), 'remote.raatik.ir');
    });
  });

  group('IDTextInputFormatter', () {
    TextEditingValue apply(String oldText, String newText) =>
        IDTextInputFormatter().formatEditUpdate(
          TextEditingValue(text: oldText),
          TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          ),
        );

    test('groups Persian-typed digits as Latin 3-3-3', () {
      final v = apply('', '۱۰۷۲۹۲۳۴۷');
      expect(v.text, '107 292 347');
      expect(v.selection.extentOffset, 11);
    });
    test('groups a pasted hyphenated ID', () {
      expect(apply('', '107-292-347').text, '107 292 347');
    });
    test('keeps caret at the end after grouping', () {
      final v = apply('107 29', '107 292');
      expect(v.text, '107 292');
      expect(v.selection.extentOffset, 7);
    });
    test('does not touch an ip:port', () {
      expect(apply('', '192.168.1.5:21118').text, '192.168.1.5:21118');
    });
    test('clears to empty', () {
      expect(apply('107', '').text, '');
    });
  });

  group('IDTextEditingController', () {
    test('id setter normalises and groups, getter returns raw digits', () {
      final c = IDTextEditingController();
      c.id = '۱۰۷-۲۹۲-۳۴۷';
      expect(c.text, '107 292 347');
      expect(c.id, '107292347');
    });
  });

  group('identifierClipboardText', () {
    test('returns raw digits without spaces or isolates', () {
      expect(identifierClipboardText('\u2066231 339 258\u2069'), '231339258');
      expect(identifierClipboardText('۲۳۱ ۳۳۹ ۲۵۸'), '231339258');
    });
    test('keeps non-ID text intact apart from bidi controls', () {
      expect(identifierClipboardText('\u2066remote.raatik.ir\u2069'),
          'remote.raatik.ir');
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `fvm flutter test test/raatik_digits_test.dart`
Expected: compile error, `digits.dart` missing and `identifierClipboardText` undefined.

- [ ] **Step 3: Implement digits.dart**

Create `flutter/lib/raatik/text/digits.dart`:

```dart
/// Digit and bidi normalisation for machine tokens (IDs, codes, ports).
/// See DESIGN-SYSTEM.md section 1.11.
library raatik_digits;

const int _persianZero = 0x06F0;
const int _arabicIndicZero = 0x0660;
const int _asciiZero = 0x30;

/// Maps Persian (U+06F0..U+06F9) and Arabic-Indic (U+0660..U+0669) digits to
/// ASCII. Everything else is returned unchanged.
String normalizeDigits(String input) {
  if (input.isEmpty) return input;
  final out = StringBuffer();
  for (final cu in input.codeUnits) {
    if (cu >= _persianZero && cu <= _persianZero + 9) {
      out.writeCharCode(_asciiZero + (cu - _persianZero));
    } else if (cu >= _arabicIndicZero && cu <= _arabicIndicZero + 9) {
      out.writeCharCode(_asciiZero + (cu - _arabicIndicZero));
    } else {
      out.writeCharCode(cu);
    }
  }
  return out.toString();
}

const Set<int> _bidiControls = {
  0x2066, 0x2067, 0x2068, 0x2069, // LRI RLI FSI PDI
  0x202A, 0x202B, 0x202C, 0x202D, 0x202E, // LRE RLE PDF LRO RLO
  0x200E, 0x200F, 0x061C, // LRM RLM ALM
};

/// Removes Unicode bidi isolate, embedding, override and mark characters.
String stripBidiControls(String input) {
  if (input.isEmpty) return input;
  return String.fromCharCodes(
      input.codeUnits.where((c) => !_bidiControls.contains(c)));
}

final RegExp _idSeparators = RegExp(r'[\s\u00A0\u202F\u2009\-]');
final RegExp _numericIdWithSuffix = RegExp(r'^\d+([\\/]r)?$');

/// Prepares typed or pasted text for the remote-ID field.
///
/// Digits are normalised and bidi controls removed. Grouping spaces and
/// hyphens are stripped only when what remains is a purely numeric ID
/// (optionally followed by the relay suffix `/r` or `\r`). Hostnames and
/// `ip:port` strings pass through with only digit normalisation applied.
String normalizeIdentifierInput(String input) {
  final cleaned = stripBidiControls(normalizeDigits(input));
  final candidate = cleaned.replaceAll(_idSeparators, '');
  if (_numericIdWithSuffix.hasMatch(candidate)) return candidate;
  return cleaned;
}
```

- [ ] **Step 4: Make the ID formatter normalise**

Replace `flutter/lib/common/formatter/id_formatter.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/raatik/bidi/ltr_isolate.dart';
import 'package:flutter_hbb/raatik/text/digits.dart';

class IDTextEditingController extends TextEditingController {
  IDTextEditingController({String? text}) : super(text: text);

  String get id => trimID(value.text);

  set id(String newID) => text = formatID(normalizeIdentifierInput(newID));
}

/// Normalises Persian/Arabic-Indic digits, strips pasted separators, then
/// applies 3-3-3 grouping. Hostnames and ip:port pass through untouched.
class IDTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    if (newValue.text == oldValue.text) {
      return newValue;
    }
    final fromRight = newValue.text.length - newValue.selection.extentOffset;
    final newID = formatID(normalizeIdentifierInput(newValue.text));
    final sameLength = newID.length == newValue.text.length;
    return TextEditingValue(
      text: newID,
      selection: TextSelection.collapsed(
        offset: (newID.length - fromRight).clamp(0, newID.length),
      ),
      // https://github.com/flutter/flutter/issues/78066#issuecomment-797869906
      composing: sameLength ? newValue.composing : TextRange.empty,
    );
  }
}

String formatID(String id) {
  String id2 = id.replaceAll(' ', '');
  String suffix = '';
  if (id2.endsWith(r'\r') || id2.endsWith(r'/r')) {
    suffix = id2.substring(id2.length - 2, id2.length);
    id2 = id2.substring(0, id2.length - 2);
  }
  if (int.tryParse(id2) == null) return id;
  String newID = '';
  if (id2.length <= 3) {
    newID = id2;
  } else {
    var n = id2.length;
    var a = n % 3 != 0 ? n % 3 : 3;
    newID = id2.substring(0, a);
    for (var i = a; i < n; i += 3) {
      newID += " ${id2.substring(i, i + 3)}";
    }
  }
  return newID + suffix;
}

String trimID(String id) {
  return id.replaceAll(' ', '');
}

String formatIDForDisplay(String id) => ltrIsolate(formatID(id));

/// What goes on the clipboard when a user copies an identifier: raw digits,
/// no grouping spaces, no bidi controls.
String identifierClipboardText(String displayText) =>
    trimID(stripBidiControls(normalizeDigits(displayText)));
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `fvm flutter test test/raatik_digits_test.dart test/raatik_bidi_test.dart`
Expected: all pass (the `formatID keeps logical groups` test in `raatik_bidi_test.dart` still passes because `formatID` is unchanged).

- [ ] **Step 6: Commit**

```bash
git add flutter/lib/raatik/text/digits.dart flutter/lib/common/formatter/id_formatter.dart flutter/test/raatik_digits_test.dart
git commit -m "feat(raatik): normalise Persian digits and pasted separators in the ID formatter

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: Digits-only formatter for codes, ports and resolutions

**Files:**
- Modify: `flutter/lib/raatik/text/digits.dart` (append)
- Modify: `flutter/lib/common/widgets/dialog.dart:313-316, 361-364, 510-513`
- Modify: `flutter/lib/desktop/widgets/remote_toolbar.dart:2349-2362`
- Modify: `flutter/lib/common/widgets/setting_widgets.dart:311-320`
- Modify: `flutter/test/raatik_digits_test.dart` (append)

**Interfaces:**
- Consumes: `normalizeDigits` from Task 3; `ltrTextDirection` from `raatik/bidi/ltr_isolate.dart`.
- Produces: `class RaatikDigitsInputFormatter extends TextInputFormatter { RaatikDigitsInputFormatter({int? maxLength, int? maxValue}); }`.

- [ ] **Step 1: Write the failing tests**

Append to `flutter/test/raatik_digits_test.dart` inside `main()`:

```dart
  group('RaatikDigitsInputFormatter', () {
    TextEditingValue apply(RaatikDigitsInputFormatter f, String text) =>
        f.formatEditUpdate(
          const TextEditingValue(text: ''),
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          ),
        );

    test('accepts Persian digits as ASCII', () {
      expect(apply(RaatikDigitsInputFormatter(), '۱۲۳۴۵۶').text, '123456');
    });
    test('drops non-digits', () {
      expect(apply(RaatikDigitsInputFormatter(), '12a-3 4').text, '1234');
    });
    test('enforces maxLength', () {
      expect(apply(RaatikDigitsInputFormatter(maxLength: 4), '192000').text,
          '1920');
    });
    test('rejects values above maxValue by keeping the old value', () {
      final f = RaatikDigitsInputFormatter(maxLength: 5, maxValue: 65535);
      final v = f.formatEditUpdate(
        const TextEditingValue(text: '6553'),
        const TextEditingValue(
            text: '65536', selection: TextSelection.collapsed(offset: 5)),
      );
      expect(v.text, '6553');
      expect(apply(f, '65535').text, '65535');
    });
    test('places the caret at the end of the cleaned text', () {
      final v = apply(RaatikDigitsInputFormatter(), '۱۲x۳');
      expect(v.text, '123');
      expect(v.selection.extentOffset, 3);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `fvm flutter test test/raatik_digits_test.dart`
Expected: compile error, `RaatikDigitsInputFormatter` undefined.

- [ ] **Step 3: Implement the formatter**

Append to `flutter/lib/raatik/text/digits.dart` (add `import 'package:flutter/services.dart';` at the top, under the `library` line):

```dart
/// Accepts only ASCII digits after normalising Persian and Arabic-Indic ones.
/// Use for 2FA codes, ports, resolutions and other short numeric fields.
/// Order matters: this must be the first formatter in the list.
class RaatikDigitsInputFormatter extends TextInputFormatter {
  RaatikDigitsInputFormatter({this.maxLength, this.maxValue});

  final int? maxLength;
  final int? maxValue;

  static final RegExp _nonDigit = RegExp(r'[^0-9]');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = normalizeDigits(newValue.text).replaceAll(_nonDigit, '');
    if (maxLength != null && text.length > maxLength!) {
      text = text.substring(0, maxLength!);
    }
    if (maxValue != null && text.isNotEmpty) {
      final parsed = int.tryParse(text);
      if (parsed == null || parsed > maxValue!) return oldValue;
    }
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `fvm flutter test test/raatik_digits_test.dart`
Expected: all pass.

- [ ] **Step 5: Apply the formatter to the existing numeric fields**

In `flutter/lib/common/widgets/dialog.dart` add the imports
`import 'package:flutter_hbb/raatik/text/digits.dart';` and
`import 'package:flutter_hbb/raatik/bidi/ltr_isolate.dart';` (the second may already exist).

At lines 313 to 316 and again at 361 to 364 (the two port fields in `changeDirectAccessPort` and the neighbouring port dialog) replace

```dart
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(
                              r'^([0-9]|[1-9]\d|[1-9]\d{2}|[1-9]\d{3}|[1-5]\d{4}|6[0-4]\d{3}|65[0-4]\d{2}|655[0-2]\d|6553[0-5])$')),
                        ],
```

with

```dart
                        inputFormatters: [
                          RaatikDigitsInputFormatter(
                              maxLength: 5, maxValue: 65535),
                        ],
```

At lines 510 to 513 (`Dialog2FaField.build`) replace

```dart
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
      ],
```

with

```dart
      inputFormatters: [RaatikDigitsInputFormatter()],
```

In `flutter/lib/desktop/widgets/remote_toolbar.dart` add `import 'package:flutter_hbb/raatik/text/digits.dart';` and replace `_resolutionInput` (lines 2349 to 2362) with:

```dart
  Widget _resolutionInput(TextEditingController controller) {
    return ltrTextDirection(
      child: TextField(
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.all(RaatikTokens.space1),
        ),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: <TextInputFormatter>[
          RaatikDigitsInputFormatter(maxLength: 4),
        ],
        controller: controller,
      ).workaroundFreezeLinuxMint(),
    );
  }
```

(`ltrTextDirection` and `RaatikTokens` are already imported in that file; if not, add `import 'package:flutter_hbb/raatik/bidi/ltr_isolate.dart';` and `import 'package:flutter_hbb/raatik/theme/tokens.dart';`.)

In `flutter/lib/common/widgets/setting_widgets.dart` lines 311 to 320, wrap the trackpad-speed `TextField` in `ltrTextDirection(child: ...)` and add `inputFormatters: [RaatikDigitsInputFormatter(maxLength: 4)],` after `keyboardType: TextInputType.number,`. Add the two imports if missing.

- [ ] **Step 6: Analyse the touched files**

Run: `fvm flutter analyze lib/common/widgets/dialog.dart lib/desktop/widgets/remote_toolbar.dart lib/common/widgets/setting_widgets.dart lib/raatik/text/digits.dart`
Expected: no errors (pre-existing infos and warnings elsewhere are acceptable; new ones in the edited lines are not).

- [ ] **Step 7: Commit**

```bash
git add flutter/lib/raatik/text/digits.dart flutter/lib/common/widgets/dialog.dart flutter/lib/desktop/widgets/remote_toolbar.dart flutter/lib/common/widgets/setting_widgets.dart flutter/test/raatik_digits_test.dart
git commit -m "feat(raatik): accept Persian digits in 2FA, port and resolution fields

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: Identifier text and field widgets

**Files:**
- Create: `flutter/lib/raatik/text/identifier_widgets.dart`
- Create: `flutter/test/raatik_identifier_widgets_test.dart`

**Interfaces:**
- Consumes: `RaatikTextStyles.identifier` (Task 2), `formatID`, `IDTextInputFormatter` (Task 3), `ltrIsolate`, `ltrTextDirection`.
- Produces:
  - `class RaatikIdentifierText extends StatelessWidget { const RaatikIdentifierText(String value, {Key? key, bool group = true, TextStyle? style, TextAlign? textAlign, TextOverflow? overflow, int? maxLines}); }`
  - `class RaatikIdentifierField extends StatelessWidget { const RaatikIdentifierField({Key? key, required TextEditingController controller, FocusNode? focusNode, bool readOnly = false, bool obscureText = false, bool autofocus = false, String? hintText, List<TextInputFormatter>? inputFormatters, ValueChanged<String>? onChanged, ValueChanged<String>? onSubmitted, GestureTapCallback? onTap, TextStyle? style, TextAlign textAlign = TextAlign.center, InputDecoration? decoration}); }`

- [ ] **Step 1: Write the failing tests**

Create `flutter/test/raatik_identifier_widgets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/raatik/text/identifier_widgets.dart';
import 'package:flutter_hbb/raatik/theme/app_theme.dart';
import 'package:flutter_hbb/raatik/theme/text_styles.dart';

Widget _rtlApp(Widget child) => MaterialApp(
      theme: buildRaatikLightTheme(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  testWidgets('RaatikIdentifierText groups, isolates and uses the Latin face',
      (tester) async {
    await tester.pumpWidget(_rtlApp(const RaatikIdentifierText('107292347')));
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, '\u2066107 292 347\u2069');
    expect(text.style?.fontFamily, kRaatikIdentifierFontFamily);
    expect(text.maxLines, 1);
  });

  testWidgets('RaatikIdentifierText(group: false) keeps secrets ungrouped',
      (tester) async {
    await tester.pumpWidget(
        _rtlApp(const RaatikIdentifierText('842915', group: false)));
    expect(tester.widget<Text>(find.byType(Text)).data, '\u2066842915\u2069');
  });

  testWidgets('RaatikIdentifierField is an LTR island with an RTL hint',
      (tester) async {
    final controller = IDTextEditingController();
    await tester.pumpWidget(_rtlApp(RaatikIdentifierField(
      controller: controller,
      hintText: 'شناسه راه دور',
      inputFormatters: [IDTextInputFormatter()],
    )));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.hintTextDirection, TextDirection.rtl);
    expect(field.textAlign, TextAlign.center);
    expect(field.style?.fontFamily, kRaatikIdentifierFontFamily);
    expect(field.autocorrect, isFalse);
    expect(Directionality.of(tester.element(find.byType(TextField))),
        TextDirection.ltr);
  });

  testWidgets('typing Persian digits yields grouped Latin digits',
      (tester) async {
    final controller = IDTextEditingController();
    await tester.pumpWidget(_rtlApp(RaatikIdentifierField(
      controller: controller,
      inputFormatters: [IDTextInputFormatter()],
    )));
    await tester.enterText(find.byType(TextField), '۱۰۷۲۹۲۳۴۷');
    await tester.pump();
    expect(controller.text, '107 292 347');
    expect(controller.id, '107292347');
  });

  testWidgets('hint follows the app direction when the app is LTR',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildRaatikLightTheme(),
      home: Scaffold(
        body: RaatikIdentifierField(
          controller: TextEditingController(),
          hintText: 'Enter Remote ID',
        ),
      ),
    ));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.hintTextDirection, TextDirection.ltr);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `fvm flutter test test/raatik_identifier_widgets_test.dart`
Expected: compile error, `identifier_widgets.dart` missing.

- [ ] **Step 3: Implement the widgets**

Create `flutter/lib/raatik/text/identifier_widgets.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/raatik/bidi/ltr_isolate.dart';
import 'package:flutter_hbb/raatik/theme/text_styles.dart';

/// Read-only identifier (ID, password, version, IP) rendered as an LTR island
/// in the Latin-digit identifier style. [group] applies 3-3-3 grouping; pass
/// false for secrets, versions and addresses.
class RaatikIdentifierText extends StatelessWidget {
  const RaatikIdentifierText(
    this.value, {
    super.key,
    this.group = true,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  final String value;
  final bool group;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final shown = group ? formatID(value) : value;
    return Text(
      ltrIsolate(shown),
      style: RaatikTextStyles.identifier(context).merge(style),
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines ?? 1,
    );
  }
}

/// Editable or read-only identifier field: an LTR island whose hint keeps the
/// app's direction. Pair with [IDTextInputFormatter] for remote IDs or
/// [RaatikDigitsInputFormatter] for codes and ports.
class RaatikIdentifierField extends StatelessWidget {
  const RaatikIdentifierField({
    super.key,
    required this.controller,
    this.focusNode,
    this.readOnly = false,
    this.obscureText = false,
    this.autofocus = false,
    this.hintText,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.style,
    this.textAlign = TextAlign.center,
    this.decoration,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool readOnly;
  final bool obscureText;
  final bool autofocus;
  final String? hintText;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final GestureTapCallback? onTap;
  final TextStyle? style;
  final TextAlign textAlign;
  final InputDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    // Captured outside the LTR island so the Persian hint stays RTL.
    final hintDirection = Directionality.of(context);
    final base = decoration ?? const InputDecoration();
    return ltrTextDirection(
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: readOnly,
        obscureText: obscureText,
        autofocus: autofocus,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.visiblePassword,
        textAlign: textAlign,
        maxLines: 1,
        style: RaatikTextStyles.identifier(context).merge(style),
        inputFormatters: inputFormatters,
        decoration: base.copyWith(
          hintText: hintText ?? base.hintText,
          hintTextDirection: hintDirection,
          counterText: '',
        ),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onTap: onTap,
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `fvm flutter test test/raatik_identifier_widgets_test.dart`
Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add flutter/lib/raatik/text/identifier_widgets.dart flutter/test/raatik_identifier_widgets_test.dart
git commit -m "feat(raatik): add RaatikIdentifierText and RaatikIdentifierField

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: Home ID and password boards, copy actions, preview harness

**Files:**
- Modify: `flutter/lib/desktop/pages/desktop_home_page.dart` (`buildIDBoard`, `buildPasswordBoard2`, `buildCopyIdPasswordCta`)
- Modify: `flutter/lib/preview/fake_home.dart` (`_CredentialRow` and its two call sites around lines 100 and 112)
- Modify: `flutter/test/raatik_bidi_test.dart` (last test)

**Interfaces:**
- Consumes: `RaatikIdentifierField`, `RaatikIdentifierText` (Task 5), `RaatikTextStyles.displayId` (Task 2), `identifierClipboardText` (Task 3).

- [ ] **Step 1: Update the preview credential row and its test first**

In `flutter/lib/preview/fake_home.dart` add
`import 'package:flutter_hbb/raatik/text/identifier_widgets.dart';` and
`import 'package:flutter_hbb/raatik/theme/text_styles.dart';`.

Change `_CredentialRow` to take a raw value and a `group` flag, and render it with `RaatikIdentifierText`:

```dart
class _CredentialRow extends StatelessWidget {
  const _CredentialRow({
    required this.label,
    required this.value,
    required this.actions,
    this.group = true,
  });

  final String label;
  final String value;
  final bool group;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.color;

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Container(width: 2, height: 48, color: RaatikTokens.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, color: muted)),
                const SizedBox(height: 4),
                ltrTextDirection(
                  child: RaatikIdentifierText(
                    value,
                    group: group,
                    style: RaatikTextStyles.displayId(context),
                  ),
                ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
```

At the call site near line 100 change `value: formatIDForDisplay('123456789'),` to `value: '123456789',` and near line 112 change `value: ltrIsolate('842915'),` to `value: '842915', group: false,`. Remove the now-unused `formatIDForDisplay` / `ltrIsolate` imports only if the analyzer reports them unused.

In `flutter/test/raatik_bidi_test.dart` the last test (`FakeHomePage credential ID uses formatIDForDisplay under fa`) keeps passing because `RaatikIdentifierText('123456789')` renders exactly `formatIDForDisplay('123456789')`. Add one assertion after `expect(find.text(expectedId), findsWidgets);`:

```dart
    final idWidget = tester.widget<Text>(find.text(expectedId).first);
    expect(idWidget.style?.fontFamily, isNot('IRANSansXFaNum'));
```

Run: `fvm flutter test test/raatik_bidi_test.dart test/raatik_responsive_matrix_test.dart`
Expected: all pass.

- [ ] **Step 2: Replace the ID board field**

In `flutter/lib/desktop/pages/desktop_home_page.dart` add the imports
`import 'package:flutter_hbb/raatik/text/identifier_widgets.dart';`,
`import 'package:flutter_hbb/raatik/theme/text_styles.dart';` and
`import 'package:flutter_hbb/common/formatter/id_formatter.dart';` (if missing).

In `buildIDBoard`, replace the `GestureDetector` child

```dart
                    child: ltrTextDirection(
                      child: TextFormField(
                        controller: model.serverId,
                        readOnly: true,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsetsDirectional.only(
                              top: 10, bottom: 10, start: 4),
                        ),
                        style: const TextStyle(
                          fontSize: 22,
                        ),
                      ).workaroundFreezeLinuxMint(),
                    ),
```

with

```dart
                    child: RaatikIdentifierField(
                      controller: model.serverId,
                      readOnly: true,
                      textAlign: TextAlign.start,
                      style: RaatikTextStyles.displayId(context),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsetsDirectional.only(
                            top: RaatikTokens.space2,
                            bottom: RaatikTokens.space2,
                            start: RaatikTokens.space1),
                      ),
                    ),
```

and change the double-tap copy to

```dart
                    onDoubleTap: () {
                      Clipboard.setData(ClipboardData(
                          text: identifierClipboardText(model.serverId.text)));
                      showToast(translate("Copied"));
                    },
```

- [ ] **Step 3: Replace the password board field**

In `buildPasswordBoard2`, replace

```dart
                          child: ltrTextDirection(
                            child: TextFormField(
                              controller: model.serverPasswd,
                              readOnly: true,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsetsDirectional.only(
                                    top: 14, bottom: 10, start: 4),
                              ),
                              style: const TextStyle(fontSize: 15),
                            ).workaroundFreezeLinuxMint(),
                          ),
```

with

```dart
                          child: RaatikIdentifierField(
                            controller: model.serverPasswd,
                            readOnly: true,
                            textAlign: TextAlign.start,
                            style: RaatikTextStyles.identifier(context,
                                fontSize: 16),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsetsDirectional.only(
                                  top: RaatikTokens.space3,
                                  bottom: RaatikTokens.space2,
                                  start: RaatikTokens.space1),
                            ),
                          ),
```

and its double-tap copy to use `identifierClipboardText(model.serverPasswd.text)`.

- [ ] **Step 4: Fix the combined copy CTA**

In `buildCopyIdPasswordCta` replace

```dart
            final id = model.serverId.text.trim();
            final pwd = model.serverPasswd.text.trim();
```

with

```dart
            final id = identifierClipboardText(model.serverId.text);
            final pwd = identifierClipboardText(model.serverPasswd.text);
```

- [ ] **Step 5: Analyse**

Run: `fvm flutter analyze lib/desktop/pages/desktop_home_page.dart lib/preview/fake_home.dart`
Expected: no errors in the edited regions.

- [ ] **Step 6: Commit**

```bash
git add flutter/lib/desktop/pages/desktop_home_page.dart flutter/lib/preview/fake_home.dart flutter/test/raatik_bidi_test.dart
git commit -m "feat(home): render own ID and password as Latin-digit LTR identifiers; copy raw digits

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: Remote-ID field, autocomplete rows, peer card IDs, search matching

**Files:**
- Modify: `flutter/lib/desktop/pages/connection_page.dart:240-300`
- Modify: `flutter/lib/common/widgets/autocomplete.dart:383-396`
- Modify: `flutter/lib/common/widgets/peer_card.dart:192-198, 381-387`
- Modify: `flutter/lib/common/widgets/peers_view.dart:395-401`
- Modify: `flutter/lib/preview/fake_home.dart` (`_FakeConnectPanel` ID field, `_PeerTile` id text)

**Interfaces:**
- Consumes: `RaatikIdentifierField`, `RaatikIdentifierText`, `RaatikTextStyles.displayId`, `normalizeDigits`, `IDTextInputFormatter`.

- [ ] **Step 1: Remote-ID field**

In `flutter/lib/desktop/pages/connection_page.dart` add the imports
`import 'package:flutter_hbb/raatik/text/identifier_widgets.dart';`,
`import 'package:flutter_hbb/raatik/text/digits.dart';`,
`import 'package:flutter_hbb/raatik/theme/text_styles.dart';`,
`import 'package:flutter_hbb/raatik/theme/tokens.dart';`.

Replace the `fieldViewBuilder` return value (the `Obx(() => ltrTextDirection(child: TextField(...)))` block, lines 276 to 300) with:

```dart
                    return Obx(() => RaatikIdentifierField(
                          controller: fieldTextEditingController,
                          focusNode: fieldFocusNode,
                          style: RaatikTextStyles.displayId(context),
                          hintText: _idInputFocused.value
                              ? null
                              : translate('Enter Remote ID'),
                          inputFormatters: [IDTextInputFormatter()],
                          decoration: const InputDecoration(
                            filled: false,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: RaatikTokens.space4,
                                vertical: RaatikTokens.space3),
                          ),
                          onChanged: (v) {
                            _idController.id = v;
                          },
                          onSubmitted: (_) {
                            onConnect();
                          },
                        ));
```

In the same `optionsBuilder` (lines 242 to 251) make matching digit-agnostic:

```dart
                      String textWithoutSpaces =
                          normalizeDigits(textEditingValue.text)
                              .replaceAll(" ", "");
```

and

```dart
                      String textToFind =
                          normalizeDigits(textEditingValue.text).toLowerCase();
```

- [ ] **Step 2: Autocomplete option rows**

In `flutter/lib/common/widgets/autocomplete.dart` add
`import 'package:flutter_hbb/raatik/text/identifier_widgets.dart';` and replace

```dart
                                                            child: Text(
                                                              ltrIsolate(
                                                                  "(${widget.peer.id})"),
                                                              style: greyStyle,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ))
```

with

```dart
                                                            child:
                                                                RaatikIdentifierText(
                                                              widget.peer.id,
                                                              style: greyStyle,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ))
```

- [ ] **Step 3: Peer card ID text (both tile and card variants)**

In `flutter/lib/common/widgets/peer_card.dart` add
`import 'package:flutter_hbb/raatik/text/identifier_widgets.dart';`. At lines 192 to 198 (and the identical block at 381 to 387) replace

```dart
                        Expanded(
                            child: Text(
                          peer.alias.isEmpty
                              ? formatIDForDisplay(peer.id)
                              : peer.alias,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        )),
```

with

```dart
                        Expanded(
                            child: peer.alias.isEmpty
                                ? RaatikIdentifierText(
                                    peer.id,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  )
                                : Text(
                                    peer.alias,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  )),
```

- [ ] **Step 4: Peer list search**

In `flutter/lib/common/widgets/peers_view.dart` add
`import 'package:flutter_hbb/raatik/text/digits.dart';` and at line 395 change
`searchText = searchText.trim();` to `searchText = normalizeDigits(searchText).trim();`.

- [ ] **Step 5: Preview harness**

In `flutter/lib/preview/fake_home.dart`, in `_FakeConnectPanel`, replace the remote-ID `TextField` (the one with the `isFa ? 'شناسه راه دور' : 'Enter Remote ID'` hint) with a `RaatikIdentifierField` using `IDTextInputFormatter()`, `RaatikTextStyles.displayId(context)` and the same hint; in `_PeerTile` replace `Text(id, style: const TextStyle(fontSize: 12))` with `RaatikIdentifierText(id, style: const TextStyle(fontSize: 12))` and change its three call sites to pass raw IDs (`'123456789'`, `'987654321'`, `'551122334'`) instead of `formatIDForDisplay(...)`.

- [ ] **Step 6: Analyse and run the matrix**

Run:

```bash
fvm flutter analyze lib/desktop/pages/connection_page.dart lib/common/widgets/autocomplete.dart lib/common/widgets/peer_card.dart lib/common/widgets/peers_view.dart lib/preview/fake_home.dart
fvm flutter test test/raatik_responsive_matrix_test.dart test/raatik_rtl_home_test.dart test/raatik_bidi_test.dart test/autocomplete_peer_merge_test.dart
```

Expected: no analyzer errors in edited regions; all tests pass.

- [ ] **Step 7: Commit**

```bash
git add flutter/lib/desktop/pages/connection_page.dart flutter/lib/common/widgets/autocomplete.dart flutter/lib/common/widgets/peer_card.dart flutter/lib/common/widgets/peers_view.dart flutter/lib/preview/fake_home.dart
git commit -m "feat(connect): remote-ID field, autocomplete and peer cards use Latin-digit LTR identifiers

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 8: Whole-suite verification, docs and preview check

**Files:**
- Modify: `raatik/design/SCREENS.md` section 6 (component-to-code map)

- [ ] **Step 1: Run the full Flutter test suite**

Run: `cd flutter && fvm flutter test`
Expected: all pass. If a test outside this plan's files fails, compare with the Task 0 baseline; a failure that also exists on the baseline is reported, not fixed here.

- [ ] **Step 2: Analyse the raatik layer and tests**

Run: `fvm flutter analyze lib/raatik lib/common/formatter lib/preview test`
Expected: no errors.

- [ ] **Step 3: Visual check in the preview harness**

Run: `fvm flutter run -d windows -t lib/preview_main.dart` (or `-d chrome`). Switch the preview to `fa`, then:

1. Type `۱۰۷۲۹۲۳۴۷` into the remote-ID field: it must show `107 292 347` in Latin digits, centred, with the Persian hint right-aligned before typing.
2. Paste `107-292-347`: same result.
3. Confirm the own-ID and password rows show Latin digits in the heavier identifier face while the labels stay in the FaNum UI font.
4. Resize the window across 640 and 1200 px: the layout switches from stacked to two columns at 640.

Take screenshots at 480, 900 and 1600 px wide and attach them to the task report.

- [ ] **Step 4: Update the component map**

In `raatik/design/SCREENS.md` section 6 change the last row to:

```
| Bidi and numbers | `ltr_isolate.dart`, `raatik/text/digits.dart`, `raatik/text/identifier_widgets.dart`, `common/formatter/id_formatter.dart` |
```

and add a row:

```
| Text styles | `raatik/theme/text_styles.dart` (`RaatikTextStyles`) |
```

- [ ] **Step 5: Commit**

```bash
git add raatik/design/SCREENS.md
git commit -m "docs(design): map number and text-style helpers in the component table

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Roadmap: the remaining plans of the redesign

Each of these is a separate plan document that must be written (with the writing-plans skill) before it is executed. They depend on Plan 1 and are listed in build order.

| Plan | Scope (DESIGN-SYSTEM sections) | Main files |
|---|---|---|
| **2. Home window shell** | top bar with utility cluster and search (2.2), nav rail (2.3), wide sidebar with your-desktop panel (2.4), hero container, connect card and your-desktop card with label chips and hover-reveal password (2.5 to 2.7), service gate placement (2.8), window class per 1.5 | `desktop_home_page.dart`, `connection_page.dart`, new `raatik/home/*` widgets, `fake_home.dart`, matrix tests |
| **3. Peer list** | segmented tab bar with filled pill (2.9), peer tile 96+40 with hued header and footer order dot → ID → kebab, list row, grid column formula, empty state (2.10), multi-select | `peer_tab_page.dart`, `peer_card.dart`, `peers_view.dart` |
| **4. Session window** | unmirrored header with new-connection, brand and tabs (2.11), toolbar cluster with monitor switcher and collapse handle (2.12), RTL menu anatomy (2.13), session tab ID via `RaatikIdentifierText` | `remote_tab_page.dart`, `tabbar_widget.dart`, `remote_toolbar.dart`, `raatik/toolbar/*`, `material_mod_popup_menu.dart` |
| **5. Dialogs and settings** | dialog frame and end-aligned actions with primary outermost (2.14), password prompt, buttons and fields (2.15 to 2.17), settings sections and rows (2.18), sliders and steppers per 1.11 | `dialog.dart`, `raatik/dialogs/*`, `desktop_setting_page.dart`, `setting_widgets.dart`, `raatik/settings/*` |

Plan 2 is the first one whose output a user sees as "the redesign"; Plans 3 to 5 can be written in parallel once Plan 2's shell widgets exist.
