import 'package:flutter/material.dart';

/// Static T1 remote toolbar mock — persistent top bar over a fake session view.
class FakeToolbarPage extends StatelessWidget {
  const FakeToolbarPage({super.key});

  static const _barColor = Color(0xFF0284C7);
  static const _danger = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sessionBg =
        isDark ? const Color(0xFF0B1220) : const Color(0xFF1E293B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          elevation: 1,
          color: _barColor,
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Image.asset(
                  'assets/logo.png',
                  width: 24,
                  height: 24,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.desktop_windows,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'RaatikDesk',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '— دفتر مرکزی',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                _barAction(Icons.folder_open_outlined, 'ارسال/دریافت فایل'),
                _barAction(Icons.chat_bubble_outline, 'گفتگو'),
                _barAction(Icons.desktop_windows_outlined, 'کنترل صفحه'),
                _barAction(Icons.more_horiz, 'بیشتر'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Material(
                    color: _danger,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.call_end, color: Colors.white, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'پایان جلسه',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: sessionBg,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.monitor,
                    size: 64,
                    color: Colors.white.withOpacity(0.25),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'نمایش جلسه ریموت (نمونه)',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _barAction(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: const Color(0x33FFFFFF),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
