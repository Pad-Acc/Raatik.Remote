import 'package:flutter/material.dart';

class RaatikWindowBrand extends StatelessWidget {
  const RaatikWindowBrand({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'RaatikDesk',
        header: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo.png', width: 22, height: 22),
            const SizedBox(width: 8),
            const Text('RaatikDesk',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
