import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';
import '../theme/tokens.dart';

enum RaatikDestination { home, history, settings }

enum RaatikSettingsSection {
  general,
  safety,
  display,
  network,
  plugin,
  account,
  printer,
  about,
}

/// Pure settings allowlist. Predicates match the historical
/// `DesktopSettingPage.tabKeys` list; this is not an authorization layer.
class RaatikSettingsAccess {
  const RaatikSettingsAccess({
    required this.isWeb,
    required this.outgoingOnly,
    required this.incomingOnly,
    required this.disableSettings,
    required this.hideSecurity,
    required this.hideNetwork,
    required this.pluginFeatureEnabled,
    required this.apiEnabled,
    required this.disableAccount,
    required this.isWindows,
    required this.hideRemotePrinter,
  });

  final bool isWeb;
  final bool outgoingOnly;
  final bool incomingOnly;
  final bool disableSettings;
  final bool hideSecurity;
  final bool hideNetwork;
  final bool pluginFeatureEnabled;
  final bool apiEnabled;
  final bool disableAccount;
  final bool isWindows;
  final bool hideRemotePrinter;

  List<RaatikSettingsSection> get sections => [
        RaatikSettingsSection.general,
        if (!isWeb && !outgoingOnly && !disableSettings && !hideSecurity)
          RaatikSettingsSection.safety,
        if (!incomingOnly) RaatikSettingsSection.display,
        if (!disableSettings && !hideNetwork) RaatikSettingsSection.network,
        if (!isWeb && !incomingOnly && pluginFeatureEnabled)
          RaatikSettingsSection.plugin,
        if (apiEnabled && !disableAccount) RaatikSettingsSection.account,
        if (isWindows && !hideRemotePrinter) RaatikSettingsSection.printer,
        RaatikSettingsSection.about,
      ];
}

/// Opens [requested] when it is allowed. A hidden section falls back to the
/// first allowed section and never runs [openHiddenSection].
RaatikSettingsSection openRaatikSettingsSection({
  required RaatikSettingsSection requested,
  required List<RaatikSettingsSection> allowed,
  required ValueChanged<RaatikSettingsSection> openSection,
  ValueChanged<RaatikSettingsSection>? openHiddenSection,
}) {
  if (allowed.contains(requested)) {
    openSection(requested);
    return requested;
  }
  final fallback =
      allowed.isEmpty ? RaatikSettingsSection.general : allowed.first;
  openSection(fallback);
  // [openHiddenSection] stays unused: a blocked deep link must not run it.
  return fallback;
}

class RaatikHomeCopy {
  const RaatikHomeCopy({
    required this.pageTitle,
    required this.receiveTitle,
    required this.connectTitle,
    required this.recentTitle,
    required this.historyTitle,
    required this.settingsTitle,
  });

  final String pageTitle;
  final String receiveTitle;
  final String connectTitle;
  final String recentTitle;
  final String historyTitle;
  final String settingsTitle;

  static RaatikHomeCopy of(Locale locale) {
    if (locale.languageCode == 'fa') {
      return const RaatikHomeCopy(
        pageTitle: 'اتصال و پشتیبانی',
        receiveTitle: 'دریافت پشتیبانی',
        connectTitle: 'اتصال به مشتری',
        recentTitle: 'دستگاه‌های اخیر',
        historyTitle: 'تاریخچهٔ جلسات',
        settingsTitle: 'تنظیمات',
      );
    }
    return const RaatikHomeCopy(
      pageTitle: 'Connection & Support',
      receiveTitle: 'Receive Support',
      connectTitle: 'Connect to Customer',
      recentTitle: 'Recent Devices',
      historyTitle: 'Session History',
      settingsTitle: 'Settings',
    );
  }
}

/// Window metrics measured before the navigation slot is removed.
class RaatikShellScope extends InheritedWidget {
  const RaatikShellScope({
    required this.clientWidth,
    required this.navigationExtent,
    required this.historyEnabled,
    required this.destination,
    required super.child,
  });

  final double clientWidth;
  final double navigationExtent;
  final bool historyEnabled;
  final ValueNotifier<RaatikDestination> destination;

  static RaatikShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RaatikShellScope>();
  }

  @override
  bool updateShouldNotify(RaatikShellScope oldWidget) {
    return clientWidth != oldWidget.clientWidth ||
        navigationExtent != oldWidget.navigationExtent ||
        historyEnabled != oldWidget.historyEnabled ||
        destination != oldWidget.destination;
  }
}

/// Per-page visibility. IndexedStack keeps state, but hidden pages must see
/// `visible == false` so their timers stop.
class RaatikPageVisibility extends InheritedWidget {
  const RaatikPageVisibility({
    required this.visible,
    required super.child,
  });

  final bool visible;

  static bool of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<RaatikPageVisibility>();
    return scope?.visible ?? true;
  }

  @override
  bool updateShouldNotify(RaatikPageVisibility oldWidget) =>
      visible != oldWidget.visible;
}

class RaatikAppShell extends StatefulWidget {
  const RaatikAppShell({
    super.key,
    required this.home,
    this.history,
    this.settings,
    required this.destination,
  });

  final Widget home;
  final Widget? history;
  final Widget? settings;
  final ValueNotifier<RaatikDestination> destination;

  @override
  State<RaatikAppShell> createState() => _RaatikAppShellState();
}

class _NavItem {
  const _NavItem({
    required this.destination,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final RaatikDestination destination;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _RaatikAppShellState extends State<RaatikAppShell> {
  final Set<RaatikDestination> _visited = <RaatikDestination>{};

  @override
  void initState() {
    super.initState();
    widget.destination.addListener(_onDestination);
    _visited.add(_effective(widget.destination.value));
  }

  @override
  void didUpdateWidget(RaatikAppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destination != widget.destination) {
      oldWidget.destination.removeListener(_onDestination);
      widget.destination.addListener(_onDestination);
    }
    _visited.add(_effective(widget.destination.value));
  }

  @override
  void dispose() {
    widget.destination.removeListener(_onDestination);
    super.dispose();
  }

  void _onDestination() {
    if (!mounted) return;
    setState(() {
      _visited.add(_effective(widget.destination.value));
    });
  }

  RaatikDestination _effective(RaatikDestination requested) {
    switch (requested) {
      case RaatikDestination.home:
        return RaatikDestination.home;
      case RaatikDestination.history:
        return widget.history == null
            ? RaatikDestination.home
            : RaatikDestination.history;
      case RaatikDestination.settings:
        return widget.settings == null
            ? RaatikDestination.home
            : RaatikDestination.settings;
    }
  }

  List<RaatikDestination> _slots() => [
        RaatikDestination.home,
        if (widget.history != null) RaatikDestination.history,
        if (widget.settings != null) RaatikDestination.settings,
      ];

  Widget _pageFor(RaatikDestination destination) {
    switch (destination) {
      case RaatikDestination.home:
        return widget.home;
      case RaatikDestination.history:
        return widget.history ?? const SizedBox.shrink();
      case RaatikDestination.settings:
        return widget.settings ?? const SizedBox.shrink();
    }
  }

  List<_NavItem> _items(RaatikHomeCopy copy) => [
        _NavItem(
          destination: RaatikDestination.home,
          label: copy.pageTitle,
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
        ),
        if (widget.history != null)
          _NavItem(
            destination: RaatikDestination.history,
            label: copy.historyTitle,
            icon: Icons.history_outlined,
            selectedIcon: Icons.history,
          ),
        if (widget.settings != null)
          _NavItem(
            destination: RaatikDestination.settings,
            label: copy.settingsTitle,
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings,
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final copy = RaatikHomeCopy.of(Localizations.localeOf(context));
    final shown = _effective(widget.destination.value);
    return LayoutBuilder(
      builder: (context, constraints) {
        final clientWidth = constraints.maxWidth;
        final windowClass = raatikWindowClassFor(clientWidth);
        final navigationExtent = _navigationExtent(windowClass);
        final body = windowClass == RaatikWindowClass.compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _content(shown)),
                  _NavigationBar(
                    items: _items(copy),
                    selected: shown,
                    layout: _NavLayout.bottom,
                    onSelect: _select,
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _NavigationBar(
                    items: _items(copy),
                    selected: shown,
                    layout: windowClass == RaatikWindowClass.wide
                        ? _NavLayout.sidebar
                        : _NavLayout.rail,
                    onSelect: _select,
                  ),
                  Expanded(child: _content(shown)),
                ],
              );
        return RaatikShellScope(
          clientWidth: clientWidth,
          navigationExtent: navigationExtent,
          historyEnabled: widget.history != null,
          destination: widget.destination,
          child: body,
        );
      },
    );
  }

  void _select(RaatikDestination destination) {
    widget.destination.value = destination;
  }

  Widget _content(RaatikDestination shown) {
    final slots = _slots();
    final index = slots.indexOf(shown);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: RaatikTokens.contentMaxWidth),
        child: SizedBox.expand(
          child: IndexedStack(
            index: index < 0 ? 0 : index,
            sizing: StackFit.expand,
            children: [
              for (final destination in slots)
                RaatikPageVisibility(
                  visible: destination == shown,
                  child: Offstage(
                    offstage: destination != shown,
                    child: TickerMode(
                      enabled: destination == shown,
                      child: _visited.contains(destination)
                          ? _pageFor(destination)
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

double _navigationExtent(RaatikWindowClass windowClass) {
  switch (windowClass) {
    case RaatikWindowClass.compact:
      return 0;
    case RaatikWindowClass.medium:
      return RaatikTokens.rail;
    case RaatikWindowClass.wide:
      return RaatikTokens.sidebar;
  }
}

enum _NavLayout { bottom, rail, sidebar }

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({
    required this.items,
    required this.selected,
    required this.layout,
    required this.onSelect,
  });

  final List<_NavItem> items;
  final RaatikDestination selected;
  final _NavLayout layout;
  final ValueChanged<RaatikDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = BorderSide(color: theme.dividerColor);
    switch (layout) {
      case _NavLayout.bottom:
        return SizedBox(
          key: const ValueKey('raatik-navigation'),
          height: RaatikTokens.rail,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: border),
            ),
            child: Row(
              children: [
                for (final item in items)
                  Expanded(
                    child: _NavButton(
                      item: item,
                      selected: item.destination == selected,
                      layout: layout,
                      onSelect: onSelect,
                    ),
                  ),
              ],
            ),
          ),
        );
      case _NavLayout.rail:
        return SizedBox(
          key: const ValueKey('raatik-navigation'),
          width: RaatikTokens.rail,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: BorderDirectional(end: border),
            ),
            child: ListView(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
              children: [
                for (final item in items)
                  _NavButton(
                    item: item,
                    selected: item.destination == selected,
                    layout: layout,
                    onSelect: onSelect,
                  ),
              ],
            ),
          ),
        );
      case _NavLayout.sidebar:
        return SizedBox(
          key: const ValueKey('raatik-navigation'),
          width: RaatikTokens.sidebar,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: BorderDirectional(end: border),
            ),
            child: ListView(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: 12,
                horizontal: 8,
              ),
              children: [
                for (final item in items)
                  _NavButton(
                    item: item,
                    selected: item.destination == selected,
                    layout: layout,
                    onSelect: onSelect,
                  ),
              ],
            ),
          ),
        );
    }
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.layout,
    required this.onSelect,
  });

  final _NavItem item;
  final bool selected;
  final _NavLayout layout;
  final ValueChanged<RaatikDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? RaatikTokens.primary
        : Theme.of(context).colorScheme.onSurface;
    final background =
        selected ? RaatikTokens.primary.withOpacity(0.12) : Colors.transparent;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : RaatikTokens.motion;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        key: ValueKey('nav-${item.destination.name}'),
        onTap: () => onSelect(item.destination),
        child: AnimatedContainer(
          duration: duration,
          curve: RaatikTokens.curve,
          constraints: const BoxConstraints(minHeight: RaatikTokens.minTarget),
          color: background,
          padding: layout == _NavLayout.sidebar
              ? const EdgeInsetsDirectional.symmetric(
                  horizontal: 12,
                  vertical: 8,
                )
              : const EdgeInsetsDirectional.symmetric(
                  horizontal: 4,
                  vertical: 4,
                ),
          child: layout == _NavLayout.sidebar
              ? _SidebarLabel(item: item, selected: selected, color: color)
              : _CompactLabel(
                  item: item,
                  selected: selected,
                  color: color,
                  rail: layout == _NavLayout.rail,
                ),
        ),
      ),
    );
  }
}

class _SidebarLabel extends StatelessWidget {
  const _SidebarLabel({
    required this.item,
    required this.selected,
    required this.color,
  });

  final _NavItem item;
  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          selected ? item.selectedIcon : item.icon,
          size: RaatikTokens.iconMd,
          color: color,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            item.label,
            softWrap: true,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactLabel extends StatelessWidget {
  const _CompactLabel({
    required this.item,
    required this.selected,
    required this.color,
    required this.rail,
  });

  final _NavItem item;
  final bool selected;
  final Color color;
  final bool rail;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final showIcon = scale < 1.5;
    final label = Text(
      item.label,
      textAlign: TextAlign.center,
      softWrap: true,
      overflow: TextOverflow.ellipsis,
      maxLines: scale >= 1.5 ? 2 : (rail ? 3 : 1),
      style: TextStyle(
        fontSize: rail ? 11 : 12,
        height: 1.1,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        color: color,
      ),
    );
    final icon = Icon(
      selected ? item.selectedIcon : item.icon,
      size: 18,
      color: color,
    );
    if (rail) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) icon,
          if (showIcon) const SizedBox(height: 4),
          label,
        ],
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showIcon) icon,
        Expanded(child: Center(child: label)),
      ],
    );
  }
}
