import 'package:flutter/material.dart';

/// Static settings shell mock — customer-first IA with sidebar groups (spec §7).
class FakeSettingsPage extends StatefulWidget {
  const FakeSettingsPage({super.key});

  @override
  State<FakeSettingsPage> createState() => _FakeSettingsPageState();
}

class _FakeSettingsPageState extends State<FakeSettingsPage> {
  int _selected = 0;

  static const _accent = Color(0xFF0891B2);

  static const _tabs = <_TabEntry>[
    _TabEntry('عمومی و ظاهر', Icons.settings_outlined, Icons.settings),
    _TabEntry('امنیت و دسترسی', Icons.enhanced_encryption_outlined,
        Icons.enhanced_encryption),
    _TabEntry('نمایش و کیفیت تصویر', Icons.desktop_windows_outlined,
        Icons.desktop_windows),
    _TabEntry('شبکه و سرور راتیک', Icons.link_outlined, Icons.link),
    _TabEntry('پیشرفته', Icons.extension_outlined, Icons.extension),
    _TabEntry('درباره RaatikDesk', Icons.info_outline, Icons.info),
  ];

  static const _groups = <_GroupEntry>[
    _GroupEntry('عمومی', 0, 2),
    _GroupEntry('برای پشتیبان', 2, 5),
    _GroupEntry('درباره', 5, 6),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebarBg = Theme.of(context).colorScheme.surface;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 220,
          child: ColoredBox(
            color: sidebarBg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 12, 8),
                  child: Text(
                    'تنظیمات',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final group in _groups) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                          child: Text(
                            group.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ),
                        for (var i = group.start; i < group.end; i++)
                          _sidebarItem(i),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: _contentForTab(_selected),
          ),
        ),
      ],
    );
  }

  Widget _sidebarItem(int index) {
    final tab = _tabs[index];
    final selected = _selected == index;
    return InkWell(
      onTap: () => setState(() => _selected = index),
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            Container(
              width: 4,
              height: 30,
              color: selected ? _accent : null,
            ),
            Icon(
              selected ? tab.selectedIcon : tab.icon,
              color: selected ? _accent : null,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              tab.label,
              style: TextStyle(
                color: selected ? _accent : null,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contentForTab(int index) {
    switch (index) {
      case 0:
        return _generalContent();
      case 1:
        return _safetyContent();
      case 2:
        return _displayContent();
      case 3:
        return _networkContent();
      case 4:
        return _advancedContent();
      case 5:
        return _aboutContent();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _card({required String title, required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 540,
      margin: const EdgeInsets.fromLTRB(15, 12, 15, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _toggleRow(String title, String subtitle, {bool value = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: (_) {}),
        ],
      ),
    );
  }

  Widget _generalContent() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _card(
          title: 'ظاهر — روشن یا تیره',
          children: [
            _radioRow('نمایه روشن', selected: true),
            _radioRow('نمایه تیره'),
          ],
        ),
        _card(
          title: 'زبان رابط',
          children: [
            _radioRow('فارسی', selected: true),
            _radioRow('English'),
          ],
        ),
        _card(
          title: 'عمومی',
          children: [
            _toggleRow(
              'اجرای همراه ویندوز',
              'برنامه با روشن شدن ویندوز خودکار اجرا می‌شود',
            ),
          ],
        ),
      ],
    );
  }

  Widget _safetyContent() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _card(
          title: 'امنیت و دسترسی',
          children: [
            _toggleRow(
              'رمز یک‌بارمصرف — هر بار رمز جدید روی صفحه اصلی',
              'هر اتصال با رمز موقت جدید تأیید می‌شود',
              value: true,
            ),
            _toggleRow(
              'پذیرش با رمز — اتصال فقط پس از وارد کردن رمز',
              'بدون رمز، هیچ کس نمی‌تواند وصل شود',
            ),
            _toggleRow(
              'تأیید دستی — قبل از اتصال از شما اجازه می‌گیرد',
              'پشتیبان باید منتظر تأیید شما بماند',
            ),
          ],
        ),
      ],
    );
  }

  Widget _displayContent() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _card(
          title: 'نمایش و کیفیت تصویر',
          children: [
            _radioRow('کیفیت بالا — تصویر واضح‌تر، اینترنت پرسرعت', selected: true),
            _radioRow('متعادل — تعادل بین کیفیت و سرعت'),
            _radioRow('سریع — برای اینترنت ضعیف؛ تصویر سریع‌تر به‌روز می‌شود'),
          ],
        ),
      ],
    );
  }

  Widget _networkContent() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _card(
          title: 'شبکه و سرور راتیک',
          children: [
            const TextField(
              decoration: InputDecoration(
                labelText: 'آدرس سرور',
                hintText: 'remote.raatik.ir',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'سرور پیش‌فرض راتیک — در صورت نیاز قابل تغییر است',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _advancedContent() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _card(
          title: 'پیشرفته',
          children: [
            _toggleRow(
              'کدک سخت‌افزاری',
              'استفاده از GPU برای فشرده‌سازی تصویر — در صورت پشتیبانی',
            ),
            _toggleRow(
              'قفل نشست هنگام قطع',
              'پس از قطع اتصال، صفحه قفل می‌شود',
            ),
          ],
        ),
      ],
    );
  }

  Widget _aboutContent() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _card(
          title: 'درباره RaatikDesk',
          children: [
            const Text('RaatikDesk'),
            const SizedBox(height: 4),
            Text(
              'نسخه ۲۰۲۶.۰۷.۰۱',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('raatik.com'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _radioRow(String label, {bool selected = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Radio<bool>(value: true, groupValue: selected, onChanged: (_) {}),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _TabEntry {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _TabEntry(this.label, this.icon, this.selectedIcon);
}

class _GroupEntry {
  final String label;
  final int start;
  final int end;
  const _GroupEntry(this.label, this.start, this.end);
}
