import 'package:flutter/material.dart';

class RaatikWindowBrand extends StatelessWidget {
  final bool showLogo;
  final bool showTitle;

  const RaatikWindowBrand({
    super.key,
    this.showLogo = true,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'RaatikDesk',
        header: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLogo) Image.asset('assets/logo.png', width: 22, height: 22),
            if (showLogo && showTitle) const SizedBox(width: 8),
            if (showTitle)
              const Text('RaatikDesk',
                  style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
