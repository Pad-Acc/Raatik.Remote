import 'package:flutter/material.dart';
import 'package:flutter_hbb/raatik/theme/tokens.dart';

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

  static const compactBreakpoint = 900.0;
  static const sidebarWidth = 232.0;
  static const compactHeaderHeight = 56.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < compactBreakpoint;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CompactHeader<T>(
                  destinations: destinations,
                  selected: selected,
                  onSelected: onSelected,
                  title: title,
                  leading: leading,
                ),
                const Divider(height: 1),
                Expanded(child: content),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: sidebarWidth,
                child: _GroupedSidebar<T>(
                  destinations: destinations,
                  selected: selected,
                  onSelected: onSelected,
                  title: title,
                  leading: leading,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          );
        },
      );
}

class _CompactHeader<T> extends StatelessWidget {
  const _CompactHeader({
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
    final selectedDestination = destinations.firstWhere(
      (d) => d.keyValue == selected,
      orElse: () => destinations.first,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: RaatikSettingsShell.compactHeaderHeight,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 12, end: 12),
        child: Row(
          children: [
            if (leading != null) leading!,
            Expanded(
              child: PopupMenuButton<T>(
                tooltip: title,
                onSelected: onSelected,
                itemBuilder: (context) => destinations
                    .map(
                      (d) => PopupMenuItem<T>(
                        value: d.keyValue,
                        child: Row(
                          children: [
                            Icon(
                              d.icon,
                              size: 20,
                              color: d.keyValue == selected
                                  ? RaatikTokens.primary
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(d.label)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(RaatikTokens.radiusSm),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(selectedDestination.icon,
                            size: 20, color: RaatikTokens.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedDestination.label,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Icon(Icons.arrow_drop_down,
                            color: colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupedSidebar<T> extends StatelessWidget {
  const _GroupedSidebar({
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

  List<String> _groups() {
    final groups = <String>[];
    for (final destination in destinations) {
      if (!groups.contains(destination.group)) {
        groups.add(destination.group);
      }
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups();
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 62,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 20, top: 10),
            child: Row(
              children: [
                if (leading != null) leading!,
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: RaatikTokens.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsetsDirectional.only(bottom: 12),
            children: [
              for (final group in groups) ...[
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 12, 6),
                  child: Text(
                    group,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final destination
                    in destinations.where((d) => d.group == group))
                  _SidebarItem<T>(
                    destination: destination,
                    selected: destination.keyValue == selected,
                    onTap: () => onSelected(destination.keyValue),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarItem<T> extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final RaatikSettingsDestination<T> destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 42,
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 29,
                  color: selected ? RaatikTokens.primary : null,
                ),
                const SizedBox(width: 9),
                Icon(
                  destination.icon,
                  color: selected ? RaatikTokens.primary : null,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    destination.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? RaatikTokens.primary : null,
                      fontWeight: FontWeight.w400,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
