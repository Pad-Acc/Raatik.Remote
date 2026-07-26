import 'package:flutter/material.dart';
import 'package:flutter_hbb/raatik/chrome/window_chrome.dart';
import 'package:flutter_hbb/raatik/theme/tokens.dart';
import 'package:flutter_hbb/raatik/toolbar/remote_toolbar_bar.dart';
import 'package:flutter_hbb/raatik/toolbar/toolbar_action.dart';

/// Preview remote toolbar using production [RaatikRemoteToolbarBar].
class FakeToolbarPage extends StatelessWidget {
  const FakeToolbarPage({super.key, required this.locale});

  final Locale locale;

  bool get _isFa => locale.languageCode == 'fa';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sessionBg =
        isDark ? RaatikTokens.darkCanvas : const Color(0xFF1E293B);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RaatikRemoteToolbarBar(
              width: width,
              brandLabel: _brandLabel(),
              primaryItems: [
                _toolbarAction(Icons.folder_open_outlined,
                    _isFa ? 'ارسال/دریافت فایل' : 'File transfer'),
                _toolbarAction(
                    Icons.chat_bubble_outline, _isFa ? 'گفتگو' : 'Chat'),
                _toolbarAction(Icons.desktop_windows_outlined,
                    _isFa ? 'کنترل صفحه' : 'Display'),
              ],
              moreMenu: _overflowAction(
                key: const Key('preview-toolbar-more'),
                label: _isFa ? 'بیشتر' : 'More',
                icon: Icons.more_horiz,
              ),
              closeMenu: _overflowAction(
                key: const Key('preview-toolbar-close'),
                label: _isFa ? 'پایان جلسه' : 'End session',
                icon: Icons.call_end,
                danger: true,
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
                        _isFa
                            ? 'نمایش جلسه ریموت (نمونه)'
                            : 'Remote session preview',
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
      },
    );
  }

  Widget _brandLabel() {
    final peer = _isFa ? 'دفتر مرکزی' : 'Head office';
    return Semantics(
      label: 'RaatikDesk $peer',
      header: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const RaatikWindowBrand(showTitle: false),
          const SizedBox(width: 6),
          const Text(
            'RaatikDesk',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            peer,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbarAction(IconData icon, String label) {
    return Semantics(
      label: label,
      button: true,
      child: RaatikToolbarFocusRing(
        child: SizedBox(
          width: RaatikRemoteToolbarBar.actionSize,
          height: RaatikRemoteToolbarBar.actionSize,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () {},
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overflowAction({
    required Key key,
    required String label,
    required IconData icon,
    bool danger = false,
  }) {
    final color = danger ? RaatikTokens.danger : const Color(0x33FFFFFF);

    return Semantics(
      label: label,
      button: true,
      child: Padding(
        key: key,
        padding: const EdgeInsetsDirectional.only(start: 4),
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
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
    );
  }
}
