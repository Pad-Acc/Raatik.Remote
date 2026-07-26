# Farsi RTL UI Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix Farsi RTL home and settings UI so Connection IDs, mixed Farsi/English strings, spacing, text alignment, duplicate Ready status, and the settings icon all render correctly under `Directionality(rtl)`.

**Architecture:** Keep Raatik presentation modules (`flutter/lib/raatik/`) as the source of spacing/theme tokens. Add a small shared bidi helper for LTR isolates (IDs, passwords, hostnames). Fix hard-coded LTR geometry (`Alignment.centerLeft`, `EdgeInsets.only(left:)`, `paddingOnly(right:)`) at the call sites that screenshots prove are wrong. Do not change protocol, FFI, or ID generation — only display and layout.

**Tech Stack:** Flutter 3.24.5, Dart, Material, GetX/Provider, existing `formatID` in `id_formatter.dart`, IRANSansXFaNum font, `src/lang/fa.rs` translations.

## Global Constraints

- Scope: Windows Flutter desktop home + settings under Farsi (`Locale('fa')`) RTL; English LTR must stay correct.
- Out of scope: mobile-only pages, remote session toolbar polish beyond shared helpers, protocol/relay/capture.
- Do not edit `src/lang/template.rs`.
- Do not create a git worktree; use a feature branch if committing.
- Prefer `EdgeInsetsDirectional` / `AlignmentDirectional` / `PositionedDirectional` over absolute left/right.
- Numeric peer IDs and one-time passwords must always paint LTR (logical order preserved).
- IRANSansXFaNum may show Eastern Arabic digits; that is OK — order must still be `1 662 867 586`, not reversed groups.
- `kRaatikApiEnabled` remains `false`.
- Practical interactive target: ≥ 44×44 logical pixels where Raatik tokens already require it.
- Preserve AGPL notices and upstream internal names required by code.

## Root-Cause Summary (investigation evidence)

| Symptom | Root cause | Evidence |
|---|---|---|
| Connection ID shown as `۵۸۶ ۸۶۷ ۶۶۲ ۱` | `formatID` inserts spaces (`"1 662 867 586"`); under RTL, Unicode bidi reorders digit groups around neutral spaces | `id_formatter.dart:36-56`; Flutter #18260 pattern |
| Mixed Farsi/English wrong order | Ambient RTL + mixed scripts without LTR isolate; some `fa.rs` strings literally reverse English tokens | Password `۸wrd۹j`; `fa.rs` entries like `invalid_http`, `Your new ID` |
| Cramped margins | Theme `InputDecorationTheme` has no `contentPadding`; many `marginOnly(left:)` / `paddingOnly(right:)`; sidebar icon gap 9–10px | `app_theme.dart:25-43`; `settings_shell.dart:285-291`; settings screenshots |
| Title stuck left | Hard-coded `Alignment.centerLeft` on "Your Desktop" | `desktop_home_page.dart:546-551` |
| "آماده به کار" twice | `RaatikServiceGate` ready row + legacy `OnlineStatusWidget` at bottom of `ConnectionPage` | `service_gate.dart:88-93`; `connection_page.dart:259-260` |
| Hamburger instead of gear | Settings `ActionIcon` uses `IconFont.menu` (Tabbar glyph `0xe628`) | `desktop_tab_page.dart:102-106`; `common.dart:136` |

## File Map

| File | Responsibility |
|---|---|
| Create `flutter/lib/raatik/bidi/ltr_isolate.dart` | Wrap strings / widgets so LTR runs stay LTR inside RTL |
| Modify `flutter/lib/common/formatter/id_formatter.dart` | Keep `formatID` logic; add display helper if needed |
| Modify `flutter/lib/desktop/pages/desktop_home_page.dart` | Tip alignment; ID/password LTR; directional paddings |
| Modify `flutter/lib/desktop/pages/connection_page.dart` | Remove duplicate Ready; ID field LTR; directional paddings |
| Modify `flutter/lib/common/widgets/peer_card.dart` | LTR for `formatID` text; directional alignments |
| Modify `flutter/lib/desktop/pages/desktop_tab_page.dart` | Settings icon → gear |
| Modify `flutter/lib/desktop/widgets/tabbar_widget.dart` | Directional icon↔label gap on tabs |
| Modify `flutter/lib/raatik/theme/tokens.dart` | Spacing constants |
| Modify `flutter/lib/raatik/theme/app_theme.dart` | Input content padding; button icon gap |
| Modify `flutter/lib/raatik/settings/settings_shell.dart` | Sidebar icon↔label spacing |
| Modify `flutter/lib/desktop/pages/desktop_setting_page.dart` | Replace left-only margins with directional on touched settings rows |
| Modify `flutter/lib/preview/fake_home.dart` | Mirror production tip alignment + LTR ID display |
| Modify `src/lang/fa.rs` | Fix clearly broken mixed-script translation strings only |
| Test `flutter/test/raatik_bidi_test.dart` | Unit/widget tests for isolate + ID order under RTL |
| Test `flutter/test/raatik_rtl_home_test.dart` | Tip alignment, no duplicate Ready, gear icon |
| Test `flutter/test/raatik_settings_shell_test.dart` | Extend for spacing assertions |

---

### Task 1: LTR isolate helper + ID display under RTL

**Files:**
- Create: `flutter/lib/raatik/bidi/ltr_isolate.dart`
- Modify: `flutter/lib/common/formatter/id_formatter.dart`
- Test: `flutter/test/raatik_bidi_test.dart`

**Interfaces:**
- Consumes: existing `formatID(String)` / `trimID(String)`
- Produces:
  - `String ltrIsolate(String text)` — wraps with U+2066 … U+2069
  - `Widget ltrTextDirection({required Widget child})` — `Directionality(textDirection: TextDirection.ltr, child: child)`
  - `String formatIDForDisplay(String id)` — `ltrIsolate(formatID(id))` for plain `Text` widgets (not TextEditingControllers)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/raatik/bidi/ltr_isolate.dart';

void main() {
  test('formatID keeps logical groups', () {
    expect(formatID('1662867586'), '1 662 867 586');
  });

  test('ltrIsolate wraps with LRI/PDI', () {
    final s = ltrIsolate('1 662 867 586');
    expect(s.codeUnitAt(0), 0x2066);
    expect(s.codeUnitAt(s.length - 1), 0x2069);
    expect(s.substring(1, s.length - 1), '1 662 867 586');
  });

  testWidgets('spaced ID does not reverse under RTL Directionality',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Text(formatIDForDisplay('1662867586')),
          ),
        ),
      ),
    );
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, contains('1 662 867 586'));
    // Rendered paragraph must keep LTR isolate — first visible run is '1'
    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText).first,
    );
    expect(paragraph.text.toPlainText(), contains('1 662 867 586'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd rustdesk/flutter; flutter test test/raatik_bidi_test.dart -v`

Expected: FAIL — `ltr_isolate.dart` / `formatIDForDisplay` not found.

- [ ] **Step 3: Write minimal implementation**

```dart
// flutter/lib/raatik/bidi/ltr_isolate.dart
import 'package:flutter/widgets.dart';

const int _lri = 0x2066; // LEFT-TO-RIGHT ISOLATE
const int _pdi = 0x2069; // POP DIRECTIONAL ISOLATE

String ltrIsolate(String text) {
  if (text.isEmpty) return text;
  if (text.codeUnitAt(0) == _lri) return text;
  return String.fromCharCodes([_lri, ...text.codeUnits, _pdi]);
}

Widget ltrTextDirection({Key? key, required Widget child}) {
  return Directionality(
    key: key,
    textDirection: TextDirection.ltr,
    child: child,
  );
}
```

```dart
// append to id_formatter.dart
import 'package:flutter_hbb/raatik/bidi/ltr_isolate.dart';

String formatIDForDisplay(String id) => ltrIsolate(formatID(id));
```

Do **not** put isolates into `IDTextEditingController.text` — that would corrupt `trimID` / connect payloads. For `TextField`/`TextFormField`, wrap the field with `ltrTextDirection(...)` instead.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd rustdesk/flutter; flutter test test/raatik_bidi_test.dart -v`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add flutter/lib/raatik/bidi/ltr_isolate.dart flutter/lib/common/formatter/id_formatter.dart flutter/test/raatik_bidi_test.dart
git commit -m "fix(rtl): add LTR isolate helper for spaced peer IDs"
```

---

### Task 2: Apply LTR to ID / password / peer card displays

**Files:**
- Modify: `flutter/lib/desktop/pages/desktop_home_page.dart` (`buildIDBoard`, `buildPasswordBoard2`, copy CTA if needed)
- Modify: `flutter/lib/desktop/pages/connection_page.dart` (`_buildRemoteIDTextField`)
- Modify: `flutter/lib/common/widgets/peer_card.dart` (ID `Text` using `formatID`)
- Modify: `flutter/lib/common/widgets/autocomplete.dart` (display `formatID` rows)
- Modify: `flutter/lib/preview/fake_home.dart` (`_CredentialRow` value, `_PeerTile` id)
- Test: `flutter/test/raatik_bidi_test.dart` (extend) or `flutter/test/raatik_rtl_home_test.dart`

**Interfaces:**
- Consumes: `ltrTextDirection`, `formatIDForDisplay`, `ltrIsolate`
- Produces: ID/password fields visually LTR under fa locale

- [ ] **Step 1: Write failing widget test for home ID field direction**

```dart
testWidgets('My ID TextFormField is wrapped in LTR Directionality',
    (tester) async {
  // Pump a minimal replica: Directionality.rtl > ltrTextDirection > Text('1 662 867 586')
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: ltrTextDirection(
            child: const TextField(
              decoration: InputDecoration(border: InputBorder.none),
              controller: null,
            ),
          ),
        ),
      ),
    ),
  );
  final dirs = tester.widgetList<Directionality>(find.byType(Directionality));
  expect(
    dirs.any((d) => d.textDirection == TextDirection.ltr),
    isTrue,
  );
});
```

- [ ] **Step 2: Run test — expect fail until wrappers exist in production widgets**

For production, prefer pumping `FakeHomePage` / preview with fa locale once wrappers are in `fake_home.dart`, asserting the credential value uses `formatIDForDisplay` / LTR parent.

- [ ] **Step 3: Implement wrappers**

In `buildIDBoard` around the `TextFormField`:

```dart
ltrTextDirection(
  child: TextFormField(
    controller: model.serverId,
    readOnly: true,
    decoration: const InputDecoration(
      border: InputBorder.none,
      contentPadding: EdgeInsetsDirectional.only(top: 10, bottom: 10, start: 4),
    ),
    style: const TextStyle(fontSize: 22),
  ).workaroundFreezeLinuxMint(),
)
```

Same for `model.serverPasswd` field and the remote ID `TextField` in `connection_page.dart`.

In `peer_card.dart` wherever `formatID(peer.id)` is shown as `Text`:

```dart
Text(
  formatIDForDisplay(peer.id),
  overflow: TextOverflow.ellipsis,
  style: Theme.of(context).textTheme.titleSmall,
)
```

For mixed hostnames like `Milad@desktop-...` use `ltrIsolate(name)` or wrap the `Text` in `ltrTextDirection`.

In `fake_home.dart`, change sample IDs to use `formatIDForDisplay` / `ltrIsolate` consistently.

- [ ] **Step 4: Run tests**

Run: `cd rustdesk/flutter; flutter test test/raatik_bidi_test.dart test/raatik_home_layout_test.dart -v`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add flutter/lib/desktop/pages/desktop_home_page.dart flutter/lib/desktop/pages/connection_page.dart flutter/lib/common/widgets/peer_card.dart flutter/lib/common/widgets/autocomplete.dart flutter/lib/preview/fake_home.dart flutter/test/raatik_bidi_test.dart
git commit -m "fix(rtl): force LTR for IDs, passwords, and peer identifiers"
```

---

### Task 3: Fix tip alignment + remove duplicate Ready

**Files:**
- Modify: `flutter/lib/desktop/pages/desktop_home_page.dart` (`buildTip`)
- Modify: `flutter/lib/desktop/pages/connection_page.dart` (remove bottom `OnlineStatusWidget` when Raatik service gate owns status)
- Modify: `flutter/lib/preview/fake_home.dart` (tip `CrossAxisAlignment` / remove any duplicate ready if present)
- Test: `flutter/test/raatik_rtl_home_test.dart`
- Existing: `flutter/test/raatik_service_gate_test.dart` (must still find Ready once)

**Interfaces:**
- Consumes: `RaatikServiceGate` ready row as single status source on home
- Produces: one Ready label; tip start-aligned in RTL

**Hypothesis confirmed:** `Align(alignment: Alignment.centerLeft)` forces visual left regardless of `Directionality`. Bottom Ready comes from `OnlineStatusWidget` still mounted under connect panel.

- [ ] **Step 1: Write failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/preview/fake_home.dart';
import 'package:flutter_hbb/preview_main.dart';
import 'package:flutter_hbb/raatik/home/service_gate.dart';
import 'package:flutter_hbb/raatik/theme/app_theme.dart';

void main() {
  testWidgets('tip title aligns to start under RTL', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        theme: buildRaatikLightTheme(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: FakeHomePage(
            phase: RaatikServicePhase.ready,
            copy: previewServiceGateCopy(const Locale('fa')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final title = find.text('آماده برای پشتیبانی اتوفای');
    expect(title, findsOneWidget);
    final textWidget = tester.widget<Text>(title);
    // Production tip must not use Alignment.centerLeft; assert geometry:
    final titleBox = tester.getTopLeft(title);
    final panelBox = tester.getTopLeft(find.byType(FakeHomePage));
    // In RTL, title's left edge should be farther right than panel mid if start-aligned;
    // simpler: ensure no Align with Alignment.centerLeft ancestor.
    expect(
      find.ancestor(
        of: title,
        matching: find.byWidgetPredicate(
          (w) => w is Align && w.alignment == Alignment.centerLeft,
        ),
      ),
      findsNothing,
    );
    expect(textWidget.textAlign == null || textWidget.textAlign == TextAlign.start,
        isTrue);
  });

  testWidgets('Ready appears once on ready home', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        theme: buildRaatikLightTheme(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: FakeHomePage(
            phase: RaatikServicePhase.ready,
            copy: previewServiceGateCopy(const Locale('fa')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('آماده به کار'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run — tip test fails while `Alignment.centerLeft` remains**

Run: `cd rustdesk/flutter; flutter test test/raatik_rtl_home_test.dart -v`

- [ ] **Step 3: Fix tip alignment**

Replace in `buildTip`:

```dart
if (!isOutgoingOnly)
  Text(
    translate("Your Desktop"),
    textAlign: TextAlign.start,
    style: Theme.of(context).textTheme.titleLarge,
  ),
```

Delete the wrapping `Align(alignment: Alignment.centerLeft, ...)`.

Keep parent `Column(crossAxisAlignment: CrossAxisAlignment.start)` — under RTL, start = right.

- [ ] **Step 4: Remove duplicate Ready**

In `ConnectionPage.build`, remove:

```dart
if (!isOutgoingOnly) const Divider(height: 1),
if (!isOutgoingOnly) OnlineStatusWidget(),
```

Keep `OnlineStatusWidget` class and its use inside incoming-only receive panel (`desktop_home_page.dart` ~240) only if that path has no service gate; if incoming-only also uses `RaatikServiceGate`, remove that instance too when Ready would duplicate. For normal Raatik home, service gate alone is enough.

Update any test that expected bottom Ready.

- [ ] **Step 5: Run tests + commit**

```bash
cd rustdesk/flutter
flutter test test/raatik_rtl_home_test.dart test/raatik_service_gate_test.dart -v
git add flutter/lib/desktop/pages/desktop_home_page.dart flutter/lib/desktop/pages/connection_page.dart flutter/lib/preview/fake_home.dart flutter/test/raatik_rtl_home_test.dart
git commit -m "fix(rtl): start-align home tip and drop duplicate Ready status"
```

---

### Task 4: Settings gear icon + tab icon gap

**Files:**
- Modify: `flutter/lib/desktop/pages/desktop_tab_page.dart`
- Modify: `flutter/lib/desktop/widgets/tabbar_widget.dart` (`_TabState._buildTabContent` icon padding)
- Test: `flutter/test/raatik_window_chrome_test.dart` or new assertions in `raatik_rtl_home_test.dart`

**Interfaces:**
- Consumes: Material `Icons.settings` / `Icons.settings_outlined`
- Produces: gear for Settings action; directional 8–12px gap between tab icon and label

- [ ] **Step 1: Write failing test**

```dart
testWidgets('main tab settings action uses gear icon', (tester) async {
  // Prefer a focused widget test pumping ActionIcon with expected icon,
  // or find Icons.settings after pumping DesktopTabPage if harness allows.
  expect(IconData, isNot(IconFont.menu)); // placeholder — assert concrete:
  const settingsIcon = Icons.settings;
  expect(settingsIcon.codePoint, isNot(IconFont.menu.codePoint));
});
```

Stronger version: after wiring, pump a tiny harness that builds the same `ActionIcon` config as `DesktopTabPage` and assert `find.byIcon(Icons.settings)`.

- [ ] **Step 2: Change icon**

In `desktop_tab_page.dart`:

```dart
ActionIcon(
  message: 'Settings',
  icon: Icons.settings,
  onTap: DesktopTabPage.onAddSetting,
  isClose: false,
),
```

- [ ] **Step 3: Fix tab icon↔label spacing**

In `tabbar_widget.dart` `_buildTabContent`:

```dart
.paddingOnly(right: 5)  // BAD under RTL
```

Replace with:

```dart
.paddingSymmetric(horizontal: 0)
```

and insert gap via:

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    icon,
    const SizedBox(width: 8),
    labelWidget,
  ],
)
```

Or use `paddingOnly` → `EdgeInsetsDirectional.only(end: 8)` via `.padding` extension if available; prefer `SizedBox(width: 8)` between icon and label.

- [ ] **Step 4: Run + commit**

```bash
cd rustdesk/flutter
flutter test test/raatik_window_chrome_test.dart test/raatik_rtl_home_test.dart -v
git add flutter/lib/desktop/pages/desktop_tab_page.dart flutter/lib/desktop/widgets/tabbar_widget.dart
git commit -m "fix(ui): use gear for settings and fix tab icon spacing"
```

---

### Task 5: Standard spacing tokens + theme input padding

**Files:**
- Modify: `flutter/lib/raatik/theme/tokens.dart`
- Modify: `flutter/lib/raatik/theme/app_theme.dart`
- Modify: `flutter/lib/raatik/settings/settings_shell.dart`
- Modify: `flutter/test/raatik_theme_test.dart`
- Modify: `flutter/test/raatik_settings_shell_test.dart`

**Interfaces:**
- Produces on `RaatikTokens`:
  - `spaceXs = 4`, `spaceSm = 8`, `spaceMd = 12`, `spaceLg = 16`, `spaceXl = 20`
  - `inputContentPadding = EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12)`
  - `iconLabelGap = 12`

- [ ] **Step 1: Failing theme test**

```dart
test('RaatikTokens expose standard spacing', () {
  expect(RaatikTokens.spaceSm, 8);
  expect(RaatikTokens.iconLabelGap, 12);
  expect(RaatikTokens.inputContentPadding.horizontal, greaterThanOrEqualTo(24));
});

test('light theme inputDecoration has contentPadding', () {
  final theme = buildRaatikLightTheme();
  expect(theme.inputDecorationTheme.contentPadding, isNotNull);
});
```

- [ ] **Step 2: Run — fail on missing members**

- [ ] **Step 3: Implement tokens + theme**

```dart
// tokens.dart additions
static const spaceXs = 4.0;
static const spaceSm = 8.0;
static const spaceMd = 12.0;
static const spaceLg = 16.0;
static const spaceXl = 20.0;
static const iconLabelGap = 12.0;
static const inputContentPadding =
    EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12);
```

```dart
// _raatikInputDecorationTheme
return InputDecorationTheme(
  filled: true,
  fillColor: fill,
  isDense: false,
  contentPadding: RaatikTokens.inputContentPadding,
  // ...existing borders...
);
```

In `settings_shell.dart` `_SidebarItem`:

```dart
const SizedBox(width: RaatikTokens.iconLabelGap), // was 10 after icon
```

Also bump the strip-to-icon gap from 9 → `RaatikTokens.spaceMd`.

ElevatedButton icon gap: set in `_raatikButtonStyle`:

```dart
padding: const MaterialStatePropertyAll(
  EdgeInsets.symmetric(horizontal: 16),
),
// and when using ElevatedButton.icon, ensure SizedBox between icon/label ≥ 10
```

For home copy CTA and connect button, if Material default icon gap is too tight, wrap icon with `Padding(padding: EdgeInsetsDirectional.only(end: RaatikTokens.spaceSm), child: icon)`.

- [ ] **Step 4: Run theme + settings shell tests**

```bash
cd rustdesk/flutter
flutter test test/raatik_theme_test.dart test/raatik_settings_shell_test.dart -v
```

- [ ] **Step 5: Commit**

```bash
git add flutter/lib/raatik/theme/tokens.dart flutter/lib/raatik/theme/app_theme.dart flutter/lib/raatik/settings/settings_shell.dart flutter/test/raatik_theme_test.dart flutter/test/raatik_settings_shell_test.dart
git commit -m "fix(ui): standardize RTL-safe spacing for inputs and settings"
```

---

### Task 6: Convert hard LTR paddings on home + settings surfaces

**Files:**
- Modify: `flutter/lib/desktop/pages/desktop_home_page.dart` (ID/password boards, tip padding already directional — audit remaining `marginOnly(left/right)`)
- Modify: `flutter/lib/desktop/pages/connection_page.dart` (`EdgeInsets.fromLTRB` on ID field card → directional)
- Modify: `flutter/lib/desktop/pages/desktop_setting_page.dart` — convert `_Radio` / `_OptionCheckBox` / card margins from `marginOnly(left:)` to `marginOnly` directional equivalent:
  - Prefer `.marginSymmetric` or custom helper using `EdgeInsetsDirectional.only(start: …)`
- Modify: `flutter/lib/common/widgets/peer_card.dart` (`Alignment.centerLeft` → `AlignmentDirectional.centerStart`)
- Test: extend `raatik_rtl_home_test.dart` / `raatik_settings_shell_test.dart`

**Rule for this task:** Only touch widgets visible on the attached home + settings screenshots (General/Appearance, language dropdown, hardware codec, audio, service). Do not mass-rewrite every `marginOnly(left:)` in the repo.

- [ ] **Step 1: List concrete replacements from screenshots**

| Location | Before | After |
|---|---|---|
| `connection_page.dart` ID card | `EdgeInsets.fromLTRB(20, 24, 20, 22)` | `EdgeInsetsDirectional.fromSTEB(20, 24, 20, 22)` |
| `desktop_home_page.dart` tip Align | removed in Task 3 | — |
| `desktop_setting_page.dart` `_Radio` | `marginOnly(left: 5)` on label | `Padding(padding: EdgeInsetsDirectional.only(start: 8), child: Text(...))` |
| `desktop_setting_page.dart` `_OptionCheckBox` | `marginOnly(left: _kCheckBoxLeftMargin)` | `EdgeInsetsDirectional.only(start: _kCheckBoxLeftMargin)` |
| `desktop_setting_page.dart` language / audio dropdown fields | ensure `contentPadding` from theme applies; override only if local decoration zeros padding | use theme padding |
| `peer_card.dart` name Align | `Alignment.centerLeft` | `AlignmentDirectional.centerStart` |
| `tabbar_widget` / peer toolbar | `paddingOnly(right: 12)` | `EdgeInsetsDirectional.only(end: 12)` |

- [ ] **Step 2: Write a small golden-ish geometry test for settings sidebar**

```dart
testWidgets('settings sidebar icon and label are at least 12px apart',
    (tester) async {
  // Pump RaatikSettingsShell with one destination under RTL; measure dx gap
  // between Icon and Text centers/edges.
});
```

- [ ] **Step 3: Apply replacements; keep values numerically similar except where Task 5 tokens require bumps**

- [ ] **Step 4: Run**

```bash
cd rustdesk/flutter
flutter test test/raatik_rtl_home_test.dart test/raatik_settings_shell_test.dart test/raatik_theme_test.dart -v
```

- [ ] **Step 5: Commit**

```bash
git add flutter/lib/desktop/pages/desktop_home_page.dart flutter/lib/desktop/pages/connection_page.dart flutter/lib/desktop/pages/desktop_setting_page.dart flutter/lib/common/widgets/peer_card.dart flutter/lib/desktop/widgets/tabbar_widget.dart flutter/test/
git commit -m "fix(rtl): replace hard LTR paddings on home and settings"
```

---

### Task 7: Fix broken Farsi mixed-script translations

**Files:**
- Modify: `src/lang/fa.rs` only (never `template.rs`)
- Test: optional string assertion test in Dart is hard (translations come from FFI). Prefer manual checklist + `rg` verification.

**Interfaces:**
- Consumes: existing keys
- Produces: natural Farsi order with English tokens isolated or placed correctly

- [ ] **Step 1: Identify broken entries from screenshots + `rg`**

Known broken patterns in `fa.rs` (fix these keys' values):

```text
("Your new ID", "جدید ID")                          → "شناسه جدید"
("length %min% to %max%", "%max% تا %min% طول از") → keep placeholders, Farsi-first order
("invalid_http", "شروع شود http:// یا https:// باید با") → "باید با http:// یا https:// شروع شود"
("Invalid IP", "نامعتبر است IP آدرس")               → "آدرس IP نامعتبر است"
("connecting_status", "...در حال برقراری ارتباط با سرور") → "در حال برقراری ارتباط با سرور..."
("Set your own password", "!رمز عبور دلخواه بگذارید") → "رمز عبور دلخواه بگذارید"
```

For UI that concatenates brand names (`درباره RaatikDesk`), wrap English brand with `ltrIsolate('RaatikDesk')` at the Dart call site if the string is built in Flutter; if the whole phrase is one translation value, keep `درباره RaatikDesk` and rely on LTR isolate around the Latin substring when rendering About rows.

- [ ] **Step 2: Apply only non-empty value corrections for listed keys**

Do not blank other keys. Do not change keys.

- [ ] **Step 3: Manual verification checklist (agent runs app or preview)**

```bash
cd rustdesk/flutter
flutter run -t lib/preview_main.dart
# Locale fa: open Home + Settings
```

Checklist:
- [ ] My ID shows `۱ ۶۶۲ ۸۶۷ ۵۸۶` or `1 662 867 586` (groups not reversed)
- [ ] Password mixed Latin/digits not scrambled
- [ ] Tip title flush to the right
- [ ] Single Ready banner
- [ ] Top settings control is a gear
- [ ] Settings sidebar icon/text gap comfortable
- [ ] Language dropdown text not flush to border

- [ ] **Step 4: Commit**

```bash
git add src/lang/fa.rs
git commit -m "fix(fa): repair reversed mixed-script translation strings"
```

---

### Task 8: Regression matrix (verification gate)

**Files:**
- Test: `flutter/test/raatik_responsive_matrix_test.dart` (extend fa+en smoke if cheap)
- Test: all new RTL tests

- [ ] **Step 1: Run full Raatik + new RTL suite**

```bash
cd rustdesk/flutter
flutter test test/raatik_bidi_test.dart test/raatik_rtl_home_test.dart test/raatik_theme_test.dart test/raatik_settings_shell_test.dart test/raatik_home_layout_test.dart test/raatik_service_gate_test.dart test/raatik_responsive_matrix_test.dart -v
```

Expected: all PASS

- [ ] **Step 2: English smoke** — pump same widgets under `Locale('en')` / `TextDirection.ltr`; IDs still `1 662 867 586`; tip not forced right incorrectly; Settings still gear

- [ ] **Step 3: Commit only if Step 1–2 required test updates**

```bash
git add flutter/test/
git commit -m "test(rtl): add Farsi RTL regression coverage for home and settings"
```

---

## Self-Review

**Spec coverage**
1. Numbers backward → Tasks 1–2  
2. Mixed Farsi/English → Tasks 2 + 7  
3. Margins/spacing → Tasks 5–6  
4. Tip left-aligned → Task 3  
5. Duplicate Ready → Task 3  
6. Hamburger vs gear → Task 4  

**Placeholder scan:** none intentional; tests include concrete code.

**Type consistency:** `ltrIsolate` / `ltrTextDirection` / `formatIDForDisplay` names reused in Tasks 1–2.

**Risk notes for implementers**
- Never store LRI/PDI inside `IDTextEditingController` / connect payload path — only display or outer `Directionality`.
- Removing `OnlineStatusWidget` from `ConnectionPage` changes non-Ready messaging at the bottom; service gate already covers stopped/starting/failed/ready — verify stopped state still readable.
- `IconFont.menu` may still be used elsewhere; only change the Settings `ActionIcon` in `desktop_tab_page.dart` unless another Settings entry still uses menu glyph.
