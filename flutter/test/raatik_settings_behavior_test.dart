import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/raatik/flags.dart';
import 'package:flutter_hbb/raatik/navigation/app_shell.dart';
import 'package:flutter_hbb/raatik/settings/settings_shell.dart';

import 'raatik_test_app.dart';

const _longError =
    'مقدار واردشده برای سرور پروکسی معتبر نیست و باید یک نام میزبان یا نشانی '
    'عددی باشد؛ این پیام طولانی برای بررسی چیدمان فشرده است و نباید از عرض '
    'صفحه بیرون بزند.';

const _networkFieldKey = ValueKey('settings-network-field');
const _networkSaveKey = ValueKey('settings-explicit-save');
const _errorKey = ValueKey('settings-field-error');
const _passwordFieldKey = ValueKey('settings-password-field');
const _passwordSaveKey = ValueKey('settings-password-save');
const _fixtureSecret = 'fixture-mask';

String? _hostError(String value) {
  if (value.contains('.') && !value.contains('%') && !value.contains(' ')) {
    return null;
  }
  return _longError;
}

RaatikSettingsDestination<RaatikSettingsSection> _destination(
  RaatikSettingsSection section,
  Locale locale,
) {
  return RaatikSettingsDestination<RaatikSettingsSection>(
    keyValue: section,
    label: raatikSettingsSectionLabel(section, locale),
    group: raatikSettingsGroupLabel(section, locale),
    icon: raatikSettingsSectionIcon(section, selected: false),
    selectedIcon: raatikSettingsSectionIcon(section, selected: true),
  );
}

List<RaatikSettingsDestination<RaatikSettingsSection>> _destinationsFor(
  List<RaatikSettingsSection> sections,
  Locale locale,
) {
  return [for (final section in sections) _destination(section, locale)];
}

Future<void> _pump(
  WidgetTester tester,
  Widget child,
  Size size, {
  Locale locale = const Locale('fa'),
  TextScaler textScaler = const TextScaler.linear(1),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    testApp(child, size: size, locale: locale, textScaler: textScaler),
  );
  await tester.pumpAndSettle();
}

class _CallbackHarness extends StatefulWidget {
  const _CallbackHarness({
    required this.writes,
    this.initial = RaatikSettingsSection.safety,
    this.includePassword = false,
    this.autofocusNetwork = false,
  });

  final List<String> writes;
  final RaatikSettingsSection initial;
  final bool includePassword;
  final bool autofocusNetwork;

  @override
  State<_CallbackHarness> createState() => _CallbackHarnessState();
}

class _CallbackHarnessState extends State<_CallbackHarness> {
  late RaatikSettingsSection _section = widget.initial;
  bool _keyboard = false;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return RaatikSettingsShell<RaatikSettingsSection>(
      title: raatikSettingsPageTitle(locale),
      destinations: [
        _destination(RaatikSettingsSection.safety, locale),
        _destination(RaatikSettingsSection.network, locale),
      ],
      selected: _section,
      onSelected: (section) => setState(() => _section = section),
      content: IndexedStack(
        index: _section == RaatikSettingsSection.safety ? 0 : 1,
        sizing: StackFit.expand,
        children: [
          ListView(
            children: [
              RaatikImmediateOption(
                optionKey: 'enable-keyboard',
                label: 'Enable keyboard/mouse',
                hint: 'کنترل صفحه‌کلید در نشست ورودی',
                value: _keyboard,
                onChanged: (value) {
                  widget.writes.add('enable-keyboard:$value');
                  setState(() => _keyboard = value);
                },
              ),
            ],
          ),
          ListView(
            children: [
              RaatikExplicitOption(
                label: 'سرور پروکسی',
                hint: 'نام میزبان. رمز در این فیلد نوشته نمی‌شود.',
                saveLabel: 'اعمال',
                fieldKey: _networkFieldKey,
                saveKey: _networkSaveKey,
                errorKey: _errorKey,
                autofocus: widget.autofocusNetwork,
                validator: _hostError,
                onSave: (value) => widget.writes.add('proxy-host:$value'),
              ),
              if (widget.includePassword) ...[
                const SizedBox(height: 16),
                RaatikExplicitOption(
                  label: 'رمز پروکسی',
                  hint: 'نمایش داده نمی‌شود',
                  saveLabel: 'ذخیرهٔ رمز',
                  obscureText: true,
                  initialValue: '',
                  fieldKey: _passwordFieldKey,
                  saveKey: _passwordSaveKey,
                  errorKey: const ValueKey('settings-password-error'),
                  onSave: (_) => widget.writes.add('password:saved'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

void main() {
  test('UI-C04 titles and the API flag stay fixed', () {
    expect(kRaatikApiEnabled, isFalse);
    expect(
      raatikSettingsSectionLabel(
        RaatikSettingsSection.general,
        const Locale('fa'),
      ),
      'عمومی و ظاهر',
    );
    expect(
      raatikSettingsSectionLabel(
        RaatikSettingsSection.safety,
        const Locale('fa'),
      ),
      'امنیت و دسترسی',
    );
    expect(
      raatikSettingsSectionLabel(
        RaatikSettingsSection.display,
        const Locale('fa'),
      ),
      'نمایش و کیفیت',
    );
    expect(
      raatikSettingsSectionLabel(
        RaatikSettingsSection.network,
        const Locale('fa'),
      ),
      'شبکه و سرور',
    );
    expect(
      raatikSettingsSectionLabel(
        RaatikSettingsSection.plugin,
        const Locale('fa'),
      ),
      'افزونه‌ها',
    );
    expect(
      raatikSettingsSectionLabel(
        RaatikSettingsSection.account,
        const Locale('fa'),
      ),
      'حساب',
    );
    expect(
      raatikSettingsSectionLabel(
        RaatikSettingsSection.printer,
        const Locale('fa'),
      ),
      'چاپگر',
    );
    expect(
      raatikSettingsSectionLabel(
        RaatikSettingsSection.about,
        const Locale('fa'),
      ),
      'دربارهٔ برنامه',
    );
    expect(
      raatikSettingsSectionLabel(
        RaatikSettingsSection.general,
        const Locale('en'),
      ),
      'General & appearance',
    );
    expect(
      raatikSettingsSectionLabel(
        RaatikSettingsSection.safety,
        const Locale('en'),
      ),
      'Security & access',
    );
    expect(
      raatikSettingsSectionLabel(
        RaatikSettingsSection.display,
        const Locale('en'),
      ),
      'Display & quality',
    );
    expect(
      raatikSettingsSectionLabel(
        RaatikSettingsSection.network,
        const Locale('en'),
      ),
      'Network & server',
    );
    expect(
      raatikSettingsSectionLabel(
        RaatikSettingsSection.plugin,
        const Locale('en'),
      ),
      'Plugins',
    );
    expect(
      raatikSettingsSectionLabel(
        RaatikSettingsSection.account,
        const Locale('en'),
      ),
      'Account',
    );
    expect(
      raatikSettingsSectionLabel(
        RaatikSettingsSection.printer,
        const Locale('en'),
      ),
      'Printer',
    );
    expect(
      raatikSettingsSectionLabel(
        RaatikSettingsSection.about,
        const Locale('en'),
      ),
      'About the app',
    );
    expect(raatikSettingsPageTitle(const Locale('fa')), 'تنظیمات');
    expect(raatikSettingsPageTitle(const Locale('en')), 'Settings');
  });

  test('hidden sections stay out of the allowlist and do not write', () {
    expect(kRaatikApiEnabled, isFalse);
    final all = const RaatikSettingsAccess(
      isWeb: false,
      outgoingOnly: false,
      incomingOnly: false,
      disableSettings: false,
      hideSecurity: false,
      hideNetwork: false,
      pluginFeatureEnabled: true,
      apiEnabled: true,
      disableAccount: false,
      isWindows: true,
      hideRemotePrinter: false,
    );
    expect(all.sections, [
      RaatikSettingsSection.general,
      RaatikSettingsSection.safety,
      RaatikSettingsSection.display,
      RaatikSettingsSection.network,
      RaatikSettingsSection.plugin,
      RaatikSettingsSection.account,
      RaatikSettingsSection.printer,
      RaatikSettingsSection.about,
    ]);

    final hidden = RaatikSettingsAccess(
      isWeb: false,
      outgoingOnly: false,
      incomingOnly: true,
      disableSettings: false,
      hideSecurity: true,
      hideNetwork: true,
      pluginFeatureEnabled: true,
      apiEnabled: kRaatikApiEnabled,
      disableAccount: false,
      isWindows: false,
      hideRemotePrinter: false,
    );
    expect(hidden.sections, const [
      RaatikSettingsSection.general,
      RaatikSettingsSection.about,
    ]);
    expect(hidden.sections.contains(RaatikSettingsSection.account), isFalse);
    expect(hidden.sections.contains(RaatikSettingsSection.plugin), isFalse);
    expect(hidden.sections.contains(RaatikSettingsSection.printer), isFalse);

    final writes = <String>[];
    final opened = openRaatikSettingsSection(
      requested: RaatikSettingsSection.safety,
      allowed: hidden.sections,
      openSection: (_) {},
      openHiddenSection: (_) => writes.add('hidden'),
    );
    expect(opened, RaatikSettingsSection.general);
    expect(writes, isEmpty);

    final supportTools = const RaatikSettingsAccess(
      isWeb: false,
      outgoingOnly: false,
      incomingOnly: false,
      disableSettings: false,
      hideSecurity: false,
      hideNetwork: false,
      pluginFeatureEnabled: true,
      apiEnabled: false,
      disableAccount: false,
      isWindows: true,
      hideRemotePrinter: false,
    );
    expect(
      supportTools.sections.contains(RaatikSettingsSection.plugin),
      isTrue,
    );
    expect(
      supportTools.sections.contains(RaatikSettingsSection.printer),
      isTrue,
    );
    expect(
      supportTools.sections.contains(RaatikSettingsSection.account),
      isFalse,
    );
  });

  testWidgets('hidden section labels are absent from the shell',
      (tester) async {
    final access = RaatikSettingsAccess(
      isWeb: false,
      outgoingOnly: false,
      incomingOnly: true,
      disableSettings: false,
      hideSecurity: true,
      hideNetwork: true,
      pluginFeatureEnabled: true,
      apiEnabled: kRaatikApiEnabled,
      disableAccount: false,
      isWindows: false,
      hideRemotePrinter: true,
    );
    await _pump(
      tester,
      RaatikSettingsShell<RaatikSettingsSection>(
        destinations: _destinationsFor(access.sections, const Locale('fa')),
        selected: access.sections.first,
        onSelected: (_) {},
        content: const SizedBox.shrink(),
      ),
      const Size(1366, 768),
    );

    expect(find.text('امنیت و دسترسی'), findsNothing);
    expect(find.text('شبکه و سرور'), findsNothing);
    expect(find.text('افزونه‌ها'), findsNothing);
    expect(find.text('چاپگر'), findsNothing);
    expect(find.text('حساب'), findsNothing);
    expect(find.text('عمومی و ظاهر'), findsOneWidget);
    expect(find.text('دربارهٔ برنامه'), findsOneWidget);
    expect(find.byKey(const ValueKey('global-save-settings')), findsNothing);
  });

  testWidgets('1366 layout shows the contract titles without a global save',
      (tester) async {
    final access = const RaatikSettingsAccess(
      isWeb: false,
      outgoingOnly: false,
      incomingOnly: false,
      disableSettings: false,
      hideSecurity: false,
      hideNetwork: false,
      pluginFeatureEnabled: true,
      apiEnabled: true,
      disableAccount: false,
      isWindows: true,
      hideRemotePrinter: false,
    );
    await _pump(
      tester,
      RaatikSettingsShell<RaatikSettingsSection>(
        title: raatikSettingsPageTitle(const Locale('fa')),
        destinations: _destinationsFor(access.sections, const Locale('fa')),
        selected: RaatikSettingsSection.general,
        onSelected: (_) {},
        content: const SizedBox(key: Key('settings-content')),
      ),
      const Size(1366, 768),
    );

    expect(find.text('تنظیمات'), findsOneWidget);
    expect(find.text('عمومی و ظاهر'), findsOneWidget);
    expect(find.text('امنیت و دسترسی'), findsOneWidget);
    expect(find.text('نمایش و کیفیت'), findsOneWidget);
    expect(find.text('شبکه و سرور'), findsOneWidget);
    expect(find.text('افزونه‌ها'), findsOneWidget);
    expect(find.text('چاپگر'), findsOneWidget);
    expect(find.text('دربارهٔ برنامه'), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey(
      'raatik-settings-section-selector',
    ))).width, 200);
    expect(tester.getSize(find.byKey(const ValueKey(
      'raatik-settings-content',
    ))).width, 900);
    expect(find.byKey(const ValueKey('global-save-settings')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('immediate toggle writes once and section changes do not',
      (tester) async {
    final writes = <String>[];
    await _pump(
      tester,
      _CallbackHarness(writes: writes),
      const Size(1366, 768),
    );

    await tester.tap(find.byKey(const ValueKey('settings-option-enable-keyboard')));
    await tester.pumpAndSettle();
    expect(writes, ['enable-keyboard:true']);

    await tester.tap(find.text('شبکه و سرور'));
    await tester.pumpAndSettle();
    expect(writes, ['enable-keyboard:true']);
    expect(find.byKey(const ValueKey('global-save-settings')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicit network save stays explicit', (tester) async {
    final writes = <String>[];
    await _pump(
      tester,
      _CallbackHarness(
        writes: writes,
        initial: RaatikSettingsSection.network,
      ),
      const Size(1366, 768),
    );

    await tester.enterText(find.byKey(_networkFieldKey), '%%%');
    await tester.pump();
    expect(writes, isEmpty);

    await tester.tap(find.byKey(_networkSaveKey));
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
    expect(find.text(_longError), findsOneWidget);

    await tester.enterText(find.byKey(_networkFieldKey), 'remote.example.test');
    await tester.pump();
    expect(writes, isEmpty);
    await tester.tap(find.byKey(_networkSaveKey));
    await tester.pumpAndSettle();
    expect(writes, ['proxy-host:remote.example.test']);

    await tester.tap(find.text('امنیت و دسترسی'));
    await tester.pumpAndSettle();
    expect(writes, ['proxy-host:remote.example.test']);
    expect(find.byKey(const ValueKey('global-save-settings')), findsNothing);
  });

  testWidgets(
      'explicit save is not saved until its future completes', (tester) async {
    final gate = Completer<void>();
    final writes = <String>[];
    const fieldKey = ValueKey('async-explicit-field');
    const saveKey = ValueKey('async-explicit-save');
    await _pump(
      tester,
      RaatikExplicitOption(
        label: 'Port',
        saveLabel: 'Apply',
        initialValue: '21118',
        fieldKey: fieldKey,
        saveKey: saveKey,
        onSave: (value) {
          writes.add(value);
          return gate.future;
        },
      ),
      const Size(1366, 768),
      locale: const Locale('en'),
    );

    await tester.enterText(find.byKey(fieldKey), '21119');
    await tester.tap(find.byKey(saveKey));
    await tester.pump();
    expect(writes, ['21119']);

    await tester.tap(find.byKey(saveKey));
    await tester.pump();
    expect(writes, ['21119', '21119']);

    gate.complete();
    await tester.pump();

    await tester.tap(find.byKey(saveKey));
    await tester.pump();
    expect(writes, ['21119', '21119']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('thrown explicit save stays unsaved for a later try',
      (tester) async {
    final writes = <String>[];
    var fail = true;
    const fieldKey = ValueKey('retry-explicit-field');
    const saveKey = ValueKey('retry-explicit-save');
    await _pump(
      tester,
      RaatikExplicitOption(
        label: 'Timeout',
        saveLabel: 'Apply',
        initialValue: '10',
        fieldKey: fieldKey,
        saveKey: saveKey,
        onSave: (value) {
          writes.add(value);
          if (fail) {
            return Future<void>.error(StateError('write failed'));
          }
          return Future<void>.value();
        },
      ),
      const Size(1366, 768),
      locale: const Locale('en'),
    );

    await tester.enterText(find.byKey(fieldKey), '12');
    await tester.tap(find.byKey(saveKey));
    await tester.pump();
    expect(writes, ['12']);

    await tester.tap(find.byKey(saveKey));
    await tester.pump();
    expect(writes, ['12', '12']);

    fail = false;
    await tester.tap(find.byKey(saveKey));
    await tester.pump();
    expect(writes, ['12', '12', '12']);

    await tester.tap(find.byKey(saveKey));
    await tester.pump();
    expect(writes, ['12', '12', '12']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled immediate option shows the reason and does not write',
      (tester) async {
    final writes = <String>[];
    await _pump(
      tester,
      RaatikSettingsShell<RaatikSettingsSection>(
        destinations: _destinationsFor(
          const [RaatikSettingsSection.safety],
          const Locale('fa'),
        ),
        selected: RaatikSettingsSection.safety,
        onSelected: (_) {},
        content: RaatikImmediateOption(
          optionKey: 'enable-keyboard',
          label: 'Enable keyboard/mouse',
          value: false,
          enabled: false,
          disabledReason: 'نشست فعال است',
          onChanged: (value) => writes.add('enable-keyboard:$value'),
        ),
      ),
      const Size(1366, 768),
    );

    await tester.tap(
      find.byKey(const ValueKey('settings-option-enable-keyboard')),
    );
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
    expect(find.text('نشست فعال است'), findsOneWidget);
  });

  testWidgets('compact RTL places a long validation error under the field',
      (tester) async {
    final writes = <String>[];
    await _pump(
      tester,
      _CallbackHarness(
        writes: writes,
        initial: RaatikSettingsSection.network,
      ),
      const Size(480, 680),
    );

    await tester.enterText(find.byKey(_networkFieldKey), 'not a host');
    await tester.tap(find.byKey(_networkSaveKey));
    await tester.pumpAndSettle();

    expect(writes, isEmpty);
    expect(find.byKey(const ValueKey('global-save-settings')), findsNothing);
    final field = tester.getRect(find.byKey(_networkFieldKey));
    final error = tester.getRect(find.byKey(_errorKey));
    expect(error.top, greaterThanOrEqualTo(field.bottom - 1));
    expect(error.right, lessThanOrEqualTo(field.right + 1));
    expect(error.left, greaterThanOrEqualTo(field.left - 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tab and shift-tab move between the field and its save button',
      (tester) async {
    final writes = <String>[];
    await _pump(
      tester,
      _CallbackHarness(
        writes: writes,
        initial: RaatikSettingsSection.network,
        autofocusNetwork: true,
      ),
      const Size(1366, 768),
      locale: const Locale('en'),
    );

    await tester.tap(find.byKey(_networkFieldKey));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(_networkFieldKey)).focusNode!.hasFocus,
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(_networkSaveKey))
          .focusNode!
          .hasFocus,
      isTrue,
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(_networkFieldKey)).focusNode!.hasFocus,
      isTrue,
    );
    expect(writes, isEmpty);

    await tester.enterText(find.byKey(_networkFieldKey), '%%%');
    await tester.tap(find.byKey(_networkSaveKey));
    await tester.pump();
    final field = tester.getRect(find.byKey(_networkFieldKey));
    final error = tester.getRect(find.byKey(_errorKey));
    expect(error.top, greaterThanOrEqualTo(field.bottom - 1));
    expect(writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('password control stays masked and saves only from its button',
      (tester) async {
    final writes = <String>[];
    await _pump(
      tester,
      _CallbackHarness(
        writes: writes,
        initial: RaatikSettingsSection.network,
        includePassword: true,
      ),
      const Size(1366, 768),
      locale: const Locale('en'),
    );

    await tester.enterText(find.byKey(_passwordFieldKey), _fixtureSecret);
    await tester.pump();
    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(_passwordFieldKey),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.obscureText, isTrue);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == _fixtureSecret,
      ),
      findsNothing,
    );
    expect(writes, isEmpty);

    await tester.tap(find.byKey(_passwordSaveKey));
    await tester.pumpAndSettle();
    expect(writes, ['password:saved']);
    expect(writes.join(), isNot(contains(_fixtureSecret)));
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == _fixtureSecret,
      ),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('global-save-settings')), findsNothing);
  });
}
