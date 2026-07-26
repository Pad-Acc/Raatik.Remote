import 'package:flutter/material.dart';

class RaatikHomeLayout extends StatelessWidget {
  const RaatikHomeLayout({
    super.key,
    required this.serviceGate,
    required this.receivePanel,
    required this.connectPanel,
    required this.blocked,
    this.showConnectPanel = true,
  });

  final Widget serviceGate;
  final Widget receivePanel;
  final Widget connectPanel;
  final bool blocked;
  final bool showConnectPanel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          final Widget panels;
          if (!showConnectPanel) {
            panels = receivePanel;
          } else if (compact) {
            panels = Column(children: [
              receivePanel,
              const SizedBox(height: 12),
              connectPanel,
            ]);
          } else {
            panels = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 14, child: receivePanel),
              const SizedBox(width: 12),
              Expanded(flex: 10, child: connectPanel),
            ]);
          }
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
