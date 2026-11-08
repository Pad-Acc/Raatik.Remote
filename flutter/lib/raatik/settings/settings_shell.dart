import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../layout/breakpoints.dart';
import '../navigation/app_shell.dart';
import '../theme/tokens.dart';

const raatikSettingsSelectorKey = ValueKey<String>(
  'raatik-settings-section-selector',
);
const raatikSettingsContentKey = ValueKey<String>('raatik-settings-content');

class RaatikSettingsDestination<T> {
  const RaatikSettingsDestination({
    required this.keyValue,
    required this.label,
    required this.group,
    required this.icon,
    this.selectedIcon,
  });

  final T keyValue;
  final String label;
  final String group;
  final IconData icon;
  final IconData? selectedIcon;

  IconData resolveIcon(bool isSelected) =>
      isSelected ? (selectedIcon ?? icon) : icon;
}

String raatikSettingsPageTitle(Locale locale) {
  return locale.languageCode == 'fa' ? 'تنظیمات' : 'Settings';
}

String raatikSettingsSectionLabel(
  RaatikSettingsSection section,
  Locale locale,
) {
  final fa = locale.languageCode == 'fa';
  switch (section) {
    case RaatikSettingsSection.general:
      return fa ? 'عمومی و ظاهر' : 'General & appearance';
    case RaatikSettingsSection.safety:
      return fa ? 'امنیت و دسترسی' : 'Security & access';
    case RaatikSettingsSection.display:
      return fa ? 'نمایش و کیفیت' : 'Display & quality';
    case RaatikSettingsSection.network:
      return fa ? 'شبکه و سرور' : 'Network & server';
    case RaatikSettingsSection.plugin:
      return fa ? 'افزونه\u200cها' : 'Plugins';
    case RaatikSettingsSection.account:
      return fa ? 'حساب' : 'Account';
    case RaatikSettingsSection.printer:
      return fa ? 'چاپگر' : 'Printer';
    case RaatikSettingsSection.about:
      return fa ? 'درباره\u0654 برنامه' : 'About the app';
  }
}

String raatikSettingsGroupLabel(
  RaatikSettingsSection section,
  Locale locale,
) {
  final fa = locale.languageCode == 'fa';
  switch (section) {
    case RaatikSettingsSection.general:
    case RaatikSettingsSection.safety:
      return fa ? 'عمومی' : 'General';
    case RaatikSettingsSection.display:
    case RaatikSettingsSection.network:
    case RaatikSettingsSection.plugin:
    case RaatikSettingsSection.printer:
      return fa ? 'برای پشتیبان' : 'For support';
    case RaatikSettingsSection.account:
      return fa ? 'حساب' : 'Account';
    case RaatikSettingsSection.about:
      return fa ? 'درباره' : 'About';
  }
}

IconData raatikSettingsSectionIcon(
  RaatikSettingsSection section, {
  required bool selected,
}) {
  switch (section) {
    case RaatikSettingsSection.general:
      return selected ? Icons.settings : Icons.settings_outlined;
    case RaatikSettingsSection.safety:
      return selected
          ? Icons.enhanced_encryption
          : Icons.enhanced_encryption_outlined;
    case RaatikSettingsSection.display:
      return selected ? Icons.desktop_windows : Icons.desktop_windows_outlined;
    case RaatikSettingsSection.network:
      return selected ? Icons.link : Icons.link_outlined;
    case RaatikSettingsSection.plugin:
      return selected ? Icons.extension : Icons.extension_outlined;
    case RaatikSettingsSection.account:
      return selected ? Icons.person : Icons.person_outline;
    case RaatikSettingsSection.printer:
      return selected ? Icons.print : Icons.print_outlined;
    case RaatikSettingsSection.about:
      return selected ? Icons.info : Icons.info_outline;
  }
}

class RaatikSettingsShell<T> extends StatelessWidget {
  const RaatikSettingsShell({
    super.key,
    required this.destinations,
    required this.selected,
    required this.onSelected,
    required this.content,
    this.title = 'Settings',
    this.leading,
  });

  final List<RaatikSettingsDestination<T>> destinations;
  final T selected;
  final ValueChanged<T> onSelected;
  final Widget content;
  final String title;
  final Widget? leading;

  static const compactHeaderHeight = 44.0;
  static const mediumRailWidth = 64.0;
  static const wideListWidth = 200.0;
  static const contentMaxWidth = 900.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scope = RaatikShellScope.maybeOf(context);
        final clientWidth = scope?.clientWidth ?? constraints.maxWidth;
        final windowClass = raatikWindowClassFor(clientWidth);
        final current = _selectedDestination(destinations, selected);
        final framed = _SettingsContentFrame(
          windowClass: windowClass,
          heading: windowClass == RaatikWindowClass.medium
              ? current?.label
              : null,
          child: content,
        );
        switch (windowClass) {
          case RaatikWindowClass.compact:
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CompactSelector<T>(
                  destinations: destinations,
                  selected: current,
                  onSelected: onSelected,
                  title: title,
                  leading: leading,
                ),
                const Divider(height: 1, thickness: 1),
                Expanded(child: framed),
              ],
            );
          case RaatikWindowClass.medium:
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _IconRail<T>(
                  destinations: destinations,
                  selected: selected,
                  onSelected: onSelected,
                  leading: leading,
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: framed),
              ],
            );
          case RaatikWindowClass.wide:
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionList<T>(
                  destinations: destinations,
                  selected: selected,
                  onSelected: onSelected,
                  title: title,
                  leading: leading,
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: framed),
              ],
            );
        }
      },
    );
  }
}

RaatikSettingsDestination<T>? _selectedDestination<T>(
  List<RaatikSettingsDestination<T>> destinations,
  T selected,
) {
  for (final destination in destinations) {
    if (destination.keyValue == selected) return destination;
  }
  if (destinations.isEmpty) return null;
  return destinations.first;
}

class _SettingsContentFrame extends StatelessWidget {
  const _SettingsContentFrame({
    required this.windowClass,
    required this.heading,
    required this.child,
  });

  final RaatikWindowClass windowClass;
  final String? heading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final margin = _settingsPageMargin(windowClass);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(
          RaatikSettingsShell.contentMaxWidth,
          constraints.maxWidth,
        );
        return Align(
          alignment: AlignmentDirectional.topCenter,
          child: SizedBox(
            key: raatikSettingsContentKey,
            width: width,
            child: Padding(
              padding: EdgeInsetsDirectional.all(margin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (heading != null) ...[
                    Text(
                      heading!,
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

double _settingsPageMargin(RaatikWindowClass windowClass) {
  switch (windowClass) {
    case RaatikWindowClass.compact:
      return RaatikTokens.space4;
    case RaatikWindowClass.medium:
      return RaatikTokens.space6;
    case RaatikWindowClass.wide:
      return RaatikTokens.space8;
  }
}

class _CompactSelector<T> extends StatelessWidget {
  const _CompactSelector({
    required this.destinations,
    required this.selected,
    required this.onSelected,
    required this.title,
    this.leading,
  });

  final List<RaatikSettingsDestination<T>> destinations;
  final RaatikSettingsDestination<T>? selected;
  final ValueChanged<T> onSelected;
  final String title;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final lockHeight = scale < 1.5;
    final label = selected?.label ?? title;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      child: Row(
        children: [
          if (leading != null) leading!,
          Expanded(
            child: SizedBox(
              key: raatikSettingsSelectorKey,
              height: lockHeight ? RaatikSettingsShell.compactHeaderHeight : null,
              child: PopupMenuButton<T>(
                padding: EdgeInsets.zero,
                tooltip: title,
                onSelected: onSelected,
                itemBuilder: (context) => [
                  for (final destination in destinations)
                    PopupMenuItem<T>(
                      value: destination.keyValue,
                      child: Row(
                        children: [
                          Icon(
                            destination.resolveIcon(
                              destination.keyValue == selected?.keyValue,
                            ),
                            size: 20,
                            color: destination.keyValue == selected?.keyValue
                                ? RaatikTokens.primary
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              destination.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: RaatikSettingsShell.compactHeaderHeight,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.outlineVariant),
                      borderRadius:
                          BorderRadius.circular(RaatikTokens.radiusSm),
                    ),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected?.resolveIcon(true) ?? Icons.settings,
                            size: 20,
                            color: RaatikTokens.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              label,
                              maxLines: lockHeight ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              softWrap: true,
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconRail<T> extends StatelessWidget {
  const _IconRail({
    required this.destinations,
    required this.selected,
    required this.onSelected,
    this.leading,
  });

  final List<RaatikSettingsDestination<T>> destinations;
  final T selected;
  final ValueChanged<T> onSelected;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: raatikSettingsSelectorKey,
      width: RaatikSettingsShell.mediumRailWidth,
      child: Column(
        children: [
          if (leading != null) leading!,
          Expanded(
            child: ListView(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
              children: [
                for (final destination in destinations)
                  _RailButton<T>(
                    destination: destination,
                    selected: destination.keyValue == selected,
                    onTap: () => onSelected(destination.keyValue),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailButton<T> extends StatelessWidget {
  const _RailButton({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final RaatikSettingsDestination<T> destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final showIcon = scale < 1.5;
    final color = selected
        ? RaatikTokens.primary
        : Theme.of(context).colorScheme.onSurface;
    final icon = Icon(
      destination.resolveIcon(selected),
      size: 20,
      color: color,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Tooltip(
        message: destination.label,
        child: Material(
          color: selected
              ? RaatikTokens.primary.withOpacity(0.12)
              : Colors.transparent,
          child: InkWell(
            key: ValueKey(destination.keyValue),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: RaatikTokens.minTarget,
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 4,
                  vertical: 4,
                ),
                child: Center(
                  child: showIcon
                      ? icon
                      : Text(
                          destination.label,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.1,
                            color: color,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionList<T> extends StatelessWidget {
  const _SectionList({
    required this.destinations,
    required this.selected,
    required this.onSelected,
    required this.title,
    this.leading,
  });

  final List<RaatikSettingsDestination<T>> destinations;
  final T selected;
  final ValueChanged<T> onSelected;
  final String title;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groups = <String>[];
    for (final destination in destinations) {
      if (!groups.contains(destination.group)) groups.add(destination.group);
    }
    return SizedBox(
      key: raatikSettingsSelectorKey,
      width: RaatikSettingsShell.wideListWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 12, 8),
            child: Row(
              children: [
                if (leading != null) leading!,
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsetsDirectional.only(bottom: 12),
              children: [
                for (final group in groups) ...[
                  if (group.isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        12,
                        12,
                        4,
                      ),
                      child: Text(
                        group,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (final destination in destinations)
                    if (destination.group == group)
                      _SectionButton<T>(
                        destination: destination,
                        selected: destination.keyValue == selected,
                        onTap: () => onSelected(destination.keyValue),
                      ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionButton<T> extends StatelessWidget {
  const _SectionButton({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final RaatikSettingsDestination<T> destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final color = selected
        ? RaatikTokens.primary
        : Theme.of(context).colorScheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Material(
        color: selected
            ? RaatikTokens.primary.withOpacity(0.12)
            : Colors.transparent,
        child: InkWell(
          key: ValueKey(destination.keyValue),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: RaatikTokens.minTarget,
              maxHeight: scale < 1.5 ? RaatikTokens.minTarget : double.infinity,
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  color: selected ? RaatikTokens.primary : null,
                ),
                const SizedBox(width: RaatikTokens.spaceMd),
                Icon(
                  destination.resolveIcon(selected),
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: RaatikTokens.iconLabelGap),
                Expanded(
                  child: Text(
                    destination.label,
                    maxLines: scale < 1.5 ? 1 : 3,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: TextStyle(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RaatikImmediateOption extends StatelessWidget {
  const RaatikImmediateOption({
    super.key,
    required this.optionKey,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.enabled = true,
    this.disabledReason,
    this.badge,
  });

  final String optionKey;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? hint;
  final bool enabled;
  final String? disabledReason;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      key: ValueKey('settings-option-$optionKey'),
      container: true,
      button: true,
      enabled: enabled,
      checked: value,
      label: label,
      child: InkWell(
        onTap: enabled ? () => onChanged(!value) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: RaatikTokens.minTarget),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: IgnorePointer(
                    child: Checkbox(
                      value: value,
                      onChanged: enabled ? (_) {} : null,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 12, end: 8),
                    child: badge!,
                  ),
                ],
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: enabled
                                ? scheme.onSurface
                                : scheme.onSurface.withOpacity(0.38),
                          ),
                        ),
                        if (hint != null)
                          Text(
                            hint!,
                            softWrap: true,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.6,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        if (!enabled && disabledReason != null)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(top: 4),
                            child: Text(
                              disabledReason!,
                              softWrap: true,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.6,
                                color: scheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RaatikExplicitOption extends StatefulWidget {
  const RaatikExplicitOption({
    super.key,
    required this.label,
    required this.onSave,
    this.hint,
    this.initialValue = '',
    this.obscureText = false,
    this.enabled = true,
    this.saveLabel = 'Apply',
    this.placeholder,
    this.validator,
    this.fieldKey,
    this.saveKey,
    this.errorKey,
    this.autofocus = false,
    this.keyboardType,
    this.inputFormatters,
    this.fieldWrapper,
    this.requireChange = true,
  });

  final String label;
  final FutureOr<void> Function(String value) onSave;
  final String? hint;
  final String initialValue;
  final bool obscureText;
  final bool enabled;
  final String saveLabel;
  final String? placeholder;
  final String? Function(String value)? validator;
  final Key? fieldKey;
  final Key? saveKey;
  final Key? errorKey;
  final bool autofocus;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget Function(Widget field)? fieldWrapper;
  final bool requireChange;

  @override
  State<RaatikExplicitOption> createState() => _RaatikExplicitOptionState();
}

class _RaatikExplicitOptionState extends State<RaatikExplicitOption> {
  late final TextEditingController _controller;
  late final FocusNode _fieldFocus;
  late final FocusNode _saveFocus;
  late String _baseline;
  String? _error;

  @override
  void initState() {
    super.initState();
    _baseline = widget.initialValue;
    _controller = TextEditingController(text: widget.initialValue);
    _fieldFocus = FocusNode();
    _saveFocus = FocusNode();
  }

  @override
  void didUpdateWidget(RaatikExplicitOption oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text == _baseline &&
        widget.initialValue != oldWidget.initialValue) {
      _baseline = widget.initialValue;
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _fieldFocus.dispose();
    _saveFocus.dispose();
    super.dispose();
  }

  Future<void> _commit() async {
    if (!widget.enabled) return;
    final value = _controller.text;
    final failure = widget.validator?.call(value);
    if (failure != null) {
      setState(() => _error = failure);
      return;
    }
    if (widget.requireChange && value == _baseline) {
      setState(() => _error = null);
      return;
    }
    setState(() => _error = null);
    try {
      await widget.onSave(value);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() => _baseline = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final field = TextField(
      key: widget.fieldKey,
      controller: _controller,
      focusNode: _fieldFocus,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      obscureText: widget.obscureText,
      autocorrect: false,
      enableSuggestions: !widget.obscureText,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      maxLines: 1,
      onChanged: (value) {
        if (_error == null) return;
        setState(() => _error = widget.validator?.call(value));
      },
      onSubmitted: widget.enabled ? (_) => unawaited(_commit()) : null,
      decoration: InputDecoration(
        hintText: widget.placeholder,
        contentPadding: RaatikTokens.inputContentPadding,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RaatikTokens.radiusSm),
        ),
      ),
    );
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.label,
            softWrap: true,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: widget.enabled
                  ? scheme.onSurface
                  : scheme.onSurface.withOpacity(0.38),
            ),
          ),
          if (widget.hint != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.hint!,
              softWrap: true,
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          widget.fieldWrapper?.call(field) ?? field,
          if (_error != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 8),
              child: Text(
                _error!,
                key: widget.errorKey,
                softWrap: true,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: scheme.error,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ElevatedButton(
              key: widget.saveKey,
              focusNode: _saveFocus,
              onPressed: widget.enabled ? () => unawaited(_commit()) : null,
              child: Text(widget.saveLabel),
            ),
          ),
        ],
      ),
    );
  }
}
