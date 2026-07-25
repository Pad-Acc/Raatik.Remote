// RaatikDesk UI preview harness — run without Rust/FFI:
//   cd flutter && flutter run -d chrome -t lib/preview_main.dart
import 'package:flutter/material.dart';
import 'preview/fake_home.dart';
import 'preview/fake_settings.dart';
import 'preview/fake_toolbar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RaatikPreviewApp());
}

class RaatikPreviewApp extends StatefulWidget {
  const RaatikPreviewApp({super.key});
  @override
  State<RaatikPreviewApp> createState() => _RaatikPreviewAppState();
}

class _RaatikPreviewAppState extends State<RaatikPreviewApp> {
  ThemeMode mode = ThemeMode.light;
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'IRANSansXFaNum',
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF0284C7),
          secondary: const Color(0xFF0891B2),
          surface: const Color(0xFFF8FAFC),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'IRANSansXFaNum',
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF38BDF8),
          secondary: const Color(0xFF22D3EE),
          surface: const Color(0xFF0F172A),
        ),
      ),
      locale: const Locale('fa'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('RaatikDesk Preview'),
          actions: [
            IconButton(
              tooltip: 'تم',
              onPressed: () => setState(() {
                mode = mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
              }),
              icon: const Icon(Icons.brightness_6),
            ),
          ],
        ),
        body: IndexedStack(
          index: tab,
          children: const [
            FakeHomePage(),
            FakeSettingsPage(),
            FakeToolbarPage(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'خانه'),
            NavigationDestination(icon: Icon(Icons.settings), label: 'تنظیمات'),
            NavigationDestination(icon: Icon(Icons.desktop_windows), label: 'نوار ریموت'),
          ],
        ),
      ),
    );
  }
}
