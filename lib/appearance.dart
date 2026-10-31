import 'package:app_icon/app_icon.dart';
import 'package:flutter/material.dart';

/// Accent colours, in the same order as tools/make_icons.py. The first one is
/// the default and uses the primary app icon.
class Accent {
  final String name;
  final Color color;
  const Accent(this.name, this.color);

  /// Alternate icon name in the asset catalog (null = primary icon).
  String? get iconName => this == accents.first ? null : 'AppIcon-$name';
}

const accents = <Accent>[
  Accent('Teal', Color(0xFF2EE6A6)),
  Accent('Tan', Color(0xFFE5A276)),
  Accent('Blue', Color(0xFF3F8EFC)),
  Accent('Indigo', Color(0xFF7480F8)),
  Accent('Purple', Color(0xFFC847E8)),
  Accent('Pink', Color(0xFFEA4C6B)),
  Accent('Red', Color(0xFFEC5550)),
  Accent('Orange', Color(0xFFF09A4A)),
  Accent('Yellow', Color(0xFFF7D64B)),
  Accent('Green', Color(0xFF6BCF6B)),
  Accent('Mint', Color(0xFF62D6C4)),
  Accent('Cyan', Color(0xFF5ACDE0)),
  Accent('Sky', Color(0xFF6DCFF6)),
];

Future<bool> applyAppIcon(Accent a) => AppIcon.set(a.iconName);

ThemeData buildTheme(Color accent) {
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: accent,
    onPrimary: accent.computeLuminance() > 0.45 ? Colors.black : Colors.white,
    surface: const Color(0xFF0E1116),
    surfaceContainerHighest: const Color(0xFF1A1F27),
  );
  return ThemeData(
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
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF0E1116),
      indicatorColor: accent.withValues(alpha: 0.22),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? accent : Colors.white70)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize: 12,
          color: s.contains(WidgetState.selected) ? accent : Colors.white70)),
    ),
  );
}

/// Row of colour circles, like iOS's accent picker.
class AccentPicker extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;
  const AccentPicker({super.key, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: accents.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final a = accents[i];
          final isSel = i == selected;
          return Semantics(
            label: '${a.name} colour',
            selected: isSel,
            button: true,
            child: GestureDetector(
              onTap: () => onSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: a.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: isSel ? 3 : 1.5),
                  boxShadow: isSel
                      ? [BoxShadow(color: a.color.withValues(alpha: 0.5), blurRadius: 10)]
                      : null,
                ),
                child: isSel
                    ? Icon(Icons.check,
                        color: a.color.computeLuminance() > 0.45 ? Colors.black : Colors.white)
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}
