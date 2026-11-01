import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

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

/// Lets a screen hand a sideways swipe to the tab bar (e.g. Search after
/// its last category).
void Function(int dir, double velocity)? swipeTabs;

class _HomeShellState extends State<HomeShell> with SingleTickerProviderStateMixin {
  int _tab = 0;
  static const _tabs = 3;

  /// Sideways offset while swiping; springs back or slides the new tab in.
  late final AnimationController _x = AnimationController.unbounded(vsync: this);
  double _drag = 0;
  static const _spring = SpringDescription(mass: 1, stiffness: 320, damping: 19);

  @override
  void initState() {
    super.initState();
    swipeTabs = _step;
  }

  @override
  void dispose() {
    swipeTabs = null;
    _x.dispose();
    super.dispose();
  }

  void _springTo(double target, {double velocity = 0}) =>
      _x.animateWith(SpringSimulation(_spring, _x.value, target, velocity / 1000));

  bool _canStep(int dir) => _tab + dir >= 0 && _tab + dir < _tabs;

  void _step(int dir, double velocity) {
    if (!_canStep(dir)) {
      HapticFeedback.lightImpact();
      _x.value = -dir * 24.0; // nudge, then bounce back
      _springTo(0, velocity: velocity);
      return;
    }
    HapticFeedback.mediumImpact();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _tab += dir);
    _x.value = dir * 90.0;
    _springTo(0, velocity: velocity);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) {
          _x.stop();
          _drag = _x.value;
        },
        onHorizontalDragUpdate: (d) {
          _drag += d.delta.dx;
          // Rubber band: follows the finger, heavier at the ends.
          _x.value = _drag * (_canStep(_drag < 0 ? 1 : -1) ? 0.5 : 0.2);
        },
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          final dir = (v.abs() > 250 ? v : -_drag) < 0 ? 1 : -1;
          if ((_drag.abs() > 70 || v.abs() > 250) && _canStep(dir)) {
            _step(dir, v);
          } else {
            _springTo(0, velocity: v);
          }
          _drag = 0;
        },
        child: AnimatedBuilder(
          animation: _x,
          builder: (_, c) => Transform.translate(offset: Offset(_x.value, 0), child: c),
          child: IndexedStack(
            index: _tab,
            children: const [
              SearchScreen(),
              FavouritesScreen(),
              SettingsScreen(),
            ],
          ),
        ),
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
                    onTap: () {
                      if (i != _tab) HapticFeedback.selectionClick();
                      setState(() => _tab = i);
                    },
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
