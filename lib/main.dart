import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'appearance.dart';
import 'cloudflare.dart';
import 'screens/favourites_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'store.dart';

final store = AppStore();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  await CloudflareSession.instance.load();
  runApp(const TorrentSearchApp());
}

class TorrentSearchApp extends StatelessWidget {
  const TorrentSearchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => MaterialApp(
        title: 'Torrent Search Engine',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(accents[store.accentIndex].color),
        home: const HomeShell(),
      ),
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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xF0101010),
          border: Border(top: BorderSide(color: Ios.separator, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 54,
            child: Row(children: [
              for (final (i, icon, label) in const [
                (0, CupertinoIcons.search, 'Search'),
                (1, CupertinoIcons.bookmark_fill, 'Saved'),
                (2, CupertinoIcons.gear_solid, 'Settings'),
              ])
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _tab = i),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(icon,
                          size: 25,
                          color: _tab == i ? Theme.of(context).colorScheme.primary : Ios.secondaryLabel),
                      const SizedBox(height: 2),
                      Text(label,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: _tab == i
                                  ? Theme.of(context).colorScheme.primary
                                  : Ios.secondaryLabel)),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
