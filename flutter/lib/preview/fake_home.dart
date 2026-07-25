import 'package:flutter/material.dart';

/// Static B1 home mock — receive-dominant RTL two-column layout.
class FakeHomePage extends StatelessWidget {
  const FakeHomePage({super.key});

  static const _accent = Color(0xFF0891B2);
  static const _primary = Color(0xFF0284C7);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 14,
            child: _panel(
              context,
              cardColor: cardColor,
              borderColor: borderColor,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Center(child: _logo()),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'RaatikDesk',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: _primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'آماده برای پشتیبانی اتوفای',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'شناسه این سیستم را برای پشتیبان بخوانید یا کپی کنید',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _idRow(context, muted),
                    const SizedBox(height: 12),
                    _passwordRow(context, muted),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 16, 16),
                      child: SizedBox(
                        height: 44,
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('کپی شناسه و رمز'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 10,
            child: _panel(
              context,
              cardColor: cardColor,
              borderColor: borderColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 12, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'اتصال به سیستم دیگر',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'برای تیم پشتیبانی',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: muted),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'شناسه مقصد',
                                hintStyle: TextStyle(color: muted),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () {},
                            style: FilledButton.styleFrom(
                              backgroundColor: _accent,
                            ),
                            child: const Text('اتصال'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'اتصالات اخیر',
                      style: TextStyle(
                        fontSize: 13,
                        color: muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _peerTile('۱۲۳۴۵۶۷۸۹', 'دفتر مرکزی', borderColor),
                        _peerTile('۹۸۷۶۵۴۳۲۱', 'لپ‌تاپ پشتیبانی', borderColor),
                        _peerTile('۵۵۱۱۲۲۳۳۴', 'سیستم مشتری', borderColor),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logo() {
    return Image.asset(
      'assets/logo.png',
      width: 64,
      height: 64,
      errorBuilder: (_, __, ___) => Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.desktop_windows, color: _primary, size: 36),
      ),
    );
  }

  Widget _panel(
    BuildContext context, {
    required Color cardColor,
    required Color borderColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withOpacity(0.45)),
      ),
      child: child,
    );
  }

  Widget _idRow(BuildContext context, Color muted) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Container(width: 2, height: 48, color: _accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('شناسه من', style: TextStyle(fontSize: 14, color: muted)),
                const SizedBox(height: 4),
                const Text(
                  '۱۲۳ ۴۵۶ ۷۸۹',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.copy, color: muted, size: 20),
            tooltip: 'کپی',
          ),
        ],
      ),
    );
  }

  Widget _passwordRow(BuildContext context, Color muted) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Container(width: 2, height: 48, color: _accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('رمز یک‌بارمصرف', style: TextStyle(fontSize: 14, color: muted)),
                const SizedBox(height: 4),
                const Text(
                  '۸۴۲۹۱۵',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.refresh, color: muted, size: 20),
            tooltip: 'بروزرسانی',
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.copy, color: muted, size: 20),
            tooltip: 'کپی',
          ),
        ],
      ),
    );
  }

  Widget _peerTile(String id, String label, Color borderColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.computer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(id, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_left, size: 20),
        ],
      ),
    );
  }
}
