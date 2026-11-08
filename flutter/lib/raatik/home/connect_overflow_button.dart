import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// File-transfer / camera / terminal menu next to Connect.
class RaatikConnectOverflowButton extends StatelessWidget {
  const RaatikConnectOverflowButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.onTapDown,
  });

  final Widget icon;
  final VoidCallback onTap;
  final GestureTapDownCallback? onTapDown;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('connect-overflow'),
      width: RaatikTokens.minTarget,
      height: RaatikTokens.minTarget,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            onTapDown: onTapDown,
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}
