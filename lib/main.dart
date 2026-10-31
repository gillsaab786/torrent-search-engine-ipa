import 'package:flutter/material.dart';

import 'screens/favourites_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'store.dart';

final store = AppStore();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  runApp(const SeedfinderApp());
}

class SeedfinderApp extends StatelessWidget {
  const SeedfinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF2EE6A6);
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: accent,
      surface: const Color(0xFF0E1116),
      surfaceContainerHighest: const Color(0xFF1A1F27),
    );
    return MaterialApp(
      title: 'Seedfinder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFF0B0D11),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B0D11),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF151A21),
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          SearchScreen(),
          FavouritesScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: const Color(0xFF0E1116),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
              icon: Icon(Icons.bookmark_border),
              selectedIcon: Icon(Icons.bookmark),
              label: 'Saved'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings'),
        ],
      ),
    );
  }
}
