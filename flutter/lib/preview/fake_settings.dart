import 'package:flutter/material.dart';
import 'package:flutter_hbb/raatik/settings/settings_shell.dart';
import 'package:flutter_hbb/raatik/theme/tokens.dart';

enum _FakeSettingsKey { general, safety, display, network, plugin, about }

/// Preview settings using production [RaatikSettingsShell].
class FakeSettingsPage extends StatefulWidget {
  const FakeSettingsPage({super.key, required this.locale});

  final Locale locale;

  @override
  State<FakeSettingsPage> createState() => _FakeSettingsPageState();
}

class _FakeSettingsPageState extends State<FakeSettingsPage> {
  _FakeSettingsKey _selected = _FakeSettingsKey.general;

  bool get _isFa => widget.locale.languageCode == 'fa';

  List<RaatikSettingsDestination<_FakeSettingsKey>> get _destinations {
    final general = _isFa ? 'عمومی' : 'General';
    final support = _isFa ? 'برای پشتیبان' : 'For support';
    final about = _isFa ? 'درباره' : 'About';

    return [
      RaatikSettingsDestination(
        keyValue: _FakeSettingsKey.general,
        label: _isFa ? 'عمومی و ظاهر' : 'General & appearance',
        group: general,
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
      ),
      RaatikSettingsDestination(
        keyValue: _FakeSettingsKey.safety,
        label: _isFa ? 'امنیت و دسترسی' : 'Security & access',
        group: general,
        icon: Icons.enhanced_encryption_outlined,
        selectedIcon: Icons.enhanced_encryption,
      ),
      RaatikSettingsDestination(
        keyValue: _FakeSettingsKey.display,
        label: _isFa ? 'نمایش و کیفیت تصویر' : 'Display & quality',
        group: support,
        icon: Icons.desktop_windows_outlined,
        selectedIcon: Icons.desktop_windows,
      ),
      RaatikSettingsDestination(
        keyValue: _FakeSettingsKey.network,
        label: _isFa ? 'شبکه و سرور راتیک' : 'Network & Raatik server',
        group: support,
        icon: Icons.link_outlined,
        selectedIcon: Icons.link,
      ),
      RaatikSettingsDestination(
        keyValue: _FakeSettingsKey.plugin,
        label: _isFa ? 'پیشرفته' : 'Advanced',
        group: support,
        icon: Icons.extension_outlined,
        selectedIcon: Icons.extension,
      ),
      RaatikSettingsDestination(
        keyValue: _FakeSettingsKey.about,
        label: _isFa ? 'درباره RaatikDesk' : 'About RaatikDesk',
        group: about,
        icon: Icons.info_outline,
        selectedIcon: Icons.info,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return RaatikSettingsShell<_FakeSettingsKey>(
      title: _isFa ? 'تنظیمات' : 'Settings',
      destinations: _destinations,
      selected: _selected,
      onSelected: (value) => setState(() => _selected = value),
      content: _contentForTab(_selected),
    );
  }

  Widget _contentForTab(_FakeSettingsKey key) {
    switch (key) {
      case _FakeSettingsKey.general:
        return _generalContent();
      case _FakeSettingsKey.safety:
        return _safetyContent();
      case _FakeSettingsKey.display:
        return _displayContent();
      case _FakeSettingsKey.network:
        return _networkContent();
      case _FakeSettingsKey.plugin:
        return _advancedContent();
      case _FakeSettingsKey.about:
        return _aboutContent();
    }
  }

  Widget _generalContent() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _SettingsCard(
          title: _isFa ? 'ظاهر — روشن یا تیره' : 'Appearance — light or dark',
          children: [
            _radioRow(_isFa ? 'نمایه روشن' : 'Light theme', selected: true),
            _radioRow(_isFa ? 'نمایه تیره' : 'Dark theme'),
          ],
        ),
        _SettingsCard(
          title: _isFa ? 'زبان رابط' : 'Interface language',
          children: [
            _radioRow('فارسی', selected: _isFa),
            _radioRow('English', selected: !_isFa),
          ],
        ),
        _SettingsCard(
          title: _isFa ? 'عمومی' : 'General',
          children: [
            _toggleRow(
              _isFa ? 'اجرای همراه ویندوز' : 'Run with Windows',
              _isFa
                  ? 'برنامه با روشن شدن ویندوز خودکار اجرا می‌شود'
                  : 'Launch automatically when Windows starts',
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
        _SettingsCard(
          title: _isFa ? 'امنیت و دسترسی' : 'Security & access',
          children: [
            _toggleRow(
              _isFa
                  ? 'رمز یک‌بارمصرف — هر بار رمز جدید روی صفحه اصلی'
                  : 'One-time password — new code on home each time',
              _isFa
                  ? 'هر اتصال با رمز موقت جدید تأیید می‌شود'
                  : 'Each connection requires a fresh temporary code',
              value: true,
            ),
            _toggleRow(
              _isFa
                  ? 'پذیرش با رمز — اتصال فقط پس از وارد کردن رمز'
                  : 'Password required — connect only after entering code',
              _isFa
                  ? 'بدون رمز، هیچ کس نمی‌تواند وصل شود'
                  : 'Nobody can connect without the password',
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
        _SettingsCard(
          title: _isFa ? 'نمایش و کیفیت تصویر' : 'Display & image quality',
          children: [
            _radioRow(
              _isFa
                  ? 'کیفیت بالا — تصویر واضح‌تر'
                  : 'High quality — sharper image',
              selected: true,
            ),
            _radioRow(_isFa ? 'متعادل — تعادل کیفیت و سرعت' : 'Balanced'),
            _radioRow(_isFa
                ? 'سریع — برای اینترنت ضعیف'
                : 'Fast — for slow networks'),
          ],
        ),
      ],
    );
  }

  Widget _networkContent() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _SettingsCard(
          title: _isFa ? 'شبکه و سرور راتیک' : 'Network & Raatik server',
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: _isFa ? 'آدرس سرور' : 'Server address',
                hintText: 'remote.raatik.ir',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isFa
                  ? 'سرور پیش‌فرض راتیک — در صورت نیاز قابل تغییر است'
                  : 'Default Raatik server — change only if needed',
              style: Theme.of(context).textTheme.bodySmall,
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
        _SettingsCard(
          title: _isFa ? 'پیشرفته' : 'Advanced',
          children: [
            _toggleRow(
              _isFa ? 'کدک سخت‌افزاری' : 'Hardware codec',
              _isFa
                  ? 'استفاده از GPU برای فشرده‌سازی تصویر'
                  : 'Use GPU for image compression when available',
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
        _SettingsCard(
          title: _isFa ? 'درباره RaatikDesk' : 'About RaatikDesk',
          children: [
            const Text('RaatikDesk'),
            const SizedBox(height: 4),
            Text(
              _isFa ? 'نسخه ۲۰۲۶.۰۷.۰۱' : 'Version 2026.07.01',
              style: Theme.of(context).textTheme.bodySmall,
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
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Switch(value: value, onChanged: (_) {}),
        ],
      ),
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 900),
      margin: const EdgeInsetsDirectional.fromSTEB(15, 12, 15, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(RaatikTokens.radiusSm),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
