import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/desktop_home_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/desktop/widgets/tabbar_widget.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:flutter_hbb/raatik/navigation/app_shell.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';

import '../../common/shared_state.dart';

class DesktopTabPage extends StatefulWidget {
  const DesktopTabPage({Key? key}) : super(key: key);

  @override
  State<DesktopTabPage> createState() => _DesktopTabPageState();

  static _DesktopTabPageState? _active;

  static SettingsTabKey? get currentSettingsRequest => _active?._pendingSection;

  static void onAddSetting(
      {SettingsTabKey initialPage = SettingsTabKey.general}) {
    final host = _active;
    if (host == null || !host.mounted) {
      debugPrintStack(label: 'Raatik shell is not mounted');
      return;
    }
    try {
      final allowed = DesktopSettingPage.tabKeys
          .map(raatikSectionFor)
          .toList(growable: false);
      openRaatikSettingsSection(
        requested: raatikSectionFor(initialPage),
        allowed: allowed,
        openSection: (section) {
          final tab = settingsTabKeyFor(section);
          host._pendingSection = tab;
          host._destination.value = RaatikDestination.settings;
          DesktopSettingPage.revealSection(tab);
        },
      );
    } catch (e) {
      debugPrintStack(label: '$e');
    }
  }
}

class _DesktopTabPageState extends State<DesktopTabPage> {
  final tabController = DesktopTabController(tabType: DesktopTabType.main);
  final _destination = ValueNotifier(RaatikDestination.home);
  SettingsTabKey _pendingSection = SettingsTabKey.general;
  String _selectedTabKey = kTabLabelHomePage;
  late final bool _incomingOnly = bind.isIncomingOnly();
  late final RaatikAppShell _shell;

  _DesktopTabPageState() {
    DesktopTabPage._active = this;
    RemoteCountState.init();
    Get.put<DesktopTabController>(tabController);
    _shell = RaatikAppShell(
      destination: _destination,
      home: const DesktopHomePage(
        key: ValueKey(kTabLabelHomePage),
      ),
      settings: DesktopSettingPage(
        key: const ValueKey(kTabLabelSettingPage),
        initialTabkey: SettingsTabKey.general,
      ),
    );
    tabController.add(TabInfo(
        key: kTabLabelHomePage,
        label: kTabLabelHomePage,
        selectedIcon: Icons.home_sharp,
        unselectedIcon: Icons.home_outlined,
        closable: false,
        page: _shell));
    if (_incomingOnly) {
      tabController.onSelected = (key) {
        _selectedTabKey = key;
        _applyIncomingOnlyWindow();
      };
    }
  }

  void _onShellDestination() {
    if (!mounted || !_incomingOnly) return;
    _applyIncomingOnlyWindow();
  }

  void _applyIncomingOnlyWindow() {
    final showHome = _selectedTabKey == kTabLabelHomePage &&
        _destination.value == RaatikDestination.home;
    if (showHome) {
      windowManager.setSize(getIncomingOnlyHomeSize());
      setResizable(false);
    } else {
      windowManager.setSize(getIncomingOnlySettingsSize());
      setResizable(true);
    }
  }

  @override
  void initState() {
    super.initState();
    _destination.addListener(_onShellDestination);
  }

  @override
  void dispose() {
    _destination.removeListener(_onShellDestination);
    if (DesktopTabPage._active == this) {
      DesktopTabPage._active = null;
    }
    _destination.dispose();
    Get.delete<DesktopTabController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabWidget = Container(
        child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.background,
            body: DesktopTab(
              controller: tabController,
              showTitle: true,
            )));
    return isMacOS || kUseCompatibleUiMode
        ? tabWidget
        : Obx(
            () => DragToResizeArea(
              resizeEdgeSize: stateGlobal.resizeEdgeSize.value,
              enableResizeEdges: windowManagerEnableResizeEdges,
              child: tabWidget,
            ),
          );
  }
}
