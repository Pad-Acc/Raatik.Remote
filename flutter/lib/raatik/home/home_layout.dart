import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';
import '../navigation/app_shell.dart';
import '../theme/tokens.dart';

class RaatikHomeLayout extends StatelessWidget {
  const RaatikHomeLayout({
    super.key,
    required this.serviceGate,
    required this.receivePanel,
    required this.connectPanel,
    required this.blocked,
    this.showConnectPanel = true,
    this.showReceivePanel = true,
    this.recent,
    this.onOpenHistory,
    this.showSectionTitles = true,
  });

  final Widget serviceGate;
  final Widget receivePanel;
  final Widget connectPanel;
  final bool blocked;
  final bool showConnectPanel;
  final bool showReceivePanel;
  final Widget? recent;
  final VoidCallback? onOpenHistory;
  final bool showSectionTitles;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final metrics = RaatikShellScope.maybeOf(context);
          final clientWidth = metrics?.clientWidth ?? constraints.maxWidth;
          final navigationExtent = metrics?.navigationExtent ?? 0;
          final slotWidth = math.max(0, clientWidth - navigationExtent);
          final contentWidth =
              math.min(slotWidth, RaatikTokens.contentMaxWidth);
          final windowClass = raatikWindowClassFor(clientWidth);
          final margin = _pageMargin(windowClass);
          final gap = _cardGap(windowClass);
          final copy = RaatikHomeCopy.of(Localizations.localeOf(context));
          final motion = MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : RaatikTokens.motion;
          final showRecent = showConnectPanel && recent != null;
          final inner = contentWidth - margin * 2;
          final cardWidth =
              showReceivePanel && showConnectPanel ? (inner - gap) / 2 : inner;
          // A card narrower than 280 stacks even when the window class is wide.
          final sideBySide = showReceivePanel &&
              showConnectPanel &&
              windowClass != RaatikWindowClass.compact &&
              cardWidth >= 280;

          final panels = _panels(
            context: context,
            copy: copy,
            gap: gap,
            sideBySide: sideBySide,
          );

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: RaatikTokens.contentMaxWidth,
              ),
              child: ListView(
                key: const ValueKey('raatik-home-content'),
                padding: EdgeInsetsDirectional.all(margin),
                children: [
                  if (showSectionTitles) ...[
                    Text(copy.pageTitle, style: _pageTitleStyle(context)),
                    SizedBox(height: gap),
                  ],
                  serviceGate,
                  SizedBox(height: gap),
                  if (!sideBySide &&
                      showSectionTitles &&
                      _singleTitle(copy) != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: 8),
                      child: Text(
                        _singleTitle(copy)!,
                        style: _cardTitleStyle(context),
                      ),
                    ),
                  AbsorbPointer(
                    absorbing: blocked,
                    child: AnimatedOpacity(
                      opacity: blocked ? .48 : 1,
                      duration: motion,
                      curve: RaatikTokens.curve,
                      child: panels,
                    ),
                  ),
                  if (showRecent) ...[
                    SizedBox(height: gap),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            copy.recentTitle,
                            style: _cardTitleStyle(context),
                          ),
                        ),
                        if (onOpenHistory != null)
                          TextButton(
                            key: const ValueKey('open-history'),
                            onPressed: onOpenHistory,
                            child: Text(copy.historyTitle),
                          ),
                      ],
                    ),
                    recent!,
                  ],
                ],
              ),
            ),
          );
        },
      );

  String? _singleTitle(RaatikHomeCopy copy) {
    if (showReceivePanel && !showConnectPanel) return copy.receiveTitle;
    if (showConnectPanel && !showReceivePanel) return copy.connectTitle;
    return null;
  }

  Widget _panels({
    required BuildContext context,
    required RaatikHomeCopy copy,
    required double gap,
    required bool sideBySide,
  }) {
    if (!showReceivePanel && showConnectPanel) return connectPanel;
    if (!showConnectPanel) return receivePanel;
    final receive = _labeled(context, copy.receiveTitle, receivePanel);
    final connect = _labeled(context, copy.connectTitle, connectPanel);
    if (!sideBySide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          receive,
          SizedBox(height: gap),
          connect,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: receive),
        SizedBox(width: gap),
        Expanded(child: connect),
      ],
    );
  }

  Widget _labeled(BuildContext context, String title, Widget panel) {
    if (!showSectionTitles) return panel;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: _cardTitleStyle(context)),
        const SizedBox(height: 8),
        panel,
      ],
    );
  }

  static TextStyle _pageTitleStyle(BuildContext context) {
    return (Theme.of(context).textTheme.titleLarge ?? const TextStyle())
        .copyWith(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      height: 1.6,
    );
  }

  static TextStyle _cardTitleStyle(BuildContext context) {
    final base = Theme.of(context).textTheme.titleMedium ?? const TextStyle();
    return base.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      height: 1.6,
    );
  }
}

double _pageMargin(RaatikWindowClass windowClass) {
  switch (windowClass) {
    case RaatikWindowClass.compact:
      return RaatikTokens.space4;
    case RaatikWindowClass.medium:
      return RaatikTokens.space6;
    case RaatikWindowClass.wide:
      return RaatikTokens.space8;
  }
}

double _cardGap(RaatikWindowClass windowClass) {
  switch (windowClass) {
    case RaatikWindowClass.compact:
      return RaatikTokens.space4;
    case RaatikWindowClass.medium:
    case RaatikWindowClass.wide:
      return RaatikTokens.space6;
  }
}
