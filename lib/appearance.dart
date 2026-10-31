import 'package:app_icon/app_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Accent colours, in the same order as tools/make_icons.py. One accent
/// tints the whole interface and the home-screen icon. The first entry is the
/// default and uses the primary app icon.
class Accent {
  final String name;
  final Color color;
  final String? label;
  const Accent(this.name, this.color, {this.label});

  String get displayName => label ?? name;

  /// Alternate icon in the asset catalog. The default colour has one too
  /// (identical to the primary icon) so switching back to it is reliable.
  String get iconName => 'AppIcon-$name';
}

const accents = <Accent>[
  Accent('Teal', Color(0xFF2EE6A6)),
  Accent('Tan', Color(0xFFD2A06E)),
  Accent('Blue', Color(0xFF0A84FF)),
  Accent('Indigo', Color(0xFF5E5CE6)),
  Accent('Purple', Color(0xFFBF5AF2)),
  Accent('Pink', Color(0xFFFF375F)),
  Accent('Red', Color(0xFFFF453A)),
  Accent('DarkRed', Color(0xFFB01220), label: 'Dark Red'),
  Accent('Orange', Color(0xFFFF9F0A)),
  Accent('Yellow', Color(0xFFFFD60A)),
  Accent('Green', Color(0xFF30D158)),
  Accent('Mint', Color(0xFF63E6E2)),
  Accent('Cyan', Color(0xFF40C8E0)),
  Accent('Sky', Color(0xFF64D2FF)),
];

Future<bool> applyAppIcon(Accent a) => AppIcon.set(a.iconName);

/// iOS dark-mode system colours used across the interface.
class Ios {
  static const background = Color(0xFF000000);
  static const grouped = Color(0xFF1C1C1E);
  static const fill = Color(0xFF2C2C2E);
  static const separator = Color(0xFF38383A);
  static const secondaryLabel = Color(0xFF8E8E93);
  static const tertiaryLabel = Color(0xFF636366);
}

Color onAccent(Color a) => a.computeLuminance() > 0.5 ? Colors.black : Colors.white;

ThemeData buildTheme(Color accent) {
  final scheme = const ColorScheme.dark().copyWith(
    primary: accent,
    onPrimary: onAccent(accent),
    secondary: accent,
    surface: Ios.background,
    onSurface: Colors.white,
    surfaceContainerHighest: Ios.fill,
    outlineVariant: Ios.separator,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Ios.background,
    canvasColor: Ios.background,
    dividerColor: Ios.separator,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.white10,
    textTheme: Typography.whiteCupertino,
    appBarTheme: AppBarTheme(
      backgroundColor: Ios.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: Colors.white,
      iconTheme: IconThemeData(color: accent),
      actionsIconTheme: IconThemeData(color: accent),
      titleTextStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
    ),
    iconTheme: IconThemeData(color: accent),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accent, textStyle: const TextStyle(fontSize: 17)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: onAccent(accent),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      inactiveTrackColor: Ios.fill,
      thumbColor: Colors.white,
      overlayShape: SliderComponentShape.noOverlay,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: accent,
      selectionColor: accent.withValues(alpha: 0.35),
      selectionHandleColor: accent,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Ios.fill,
      contentTextStyle: TextStyle(color: Colors.white, fontSize: 15),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Ios.grouped,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: Ios.tertiaryLabel,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Ios.grouped, surfaceTintColor: Colors.transparent),
    popupMenuTheme: const PopupMenuThemeData(color: Ios.fill, surfaceTintColor: Colors.transparent),
    cupertinoOverrideTheme: CupertinoThemeData(primaryColor: accent, brightness: Brightness.dark),
  );
}

/// Row of colour circles. The selected one gets a white ring.
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
            label: '${a.displayName} colour',
            selected: isSel,
            button: true,
            child: GestureDetector(
              onTap: () => onSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 52,
                height: 52,
                padding: EdgeInsets.all(isSel ? 4 : 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: isSel ? 2.5 : 1.5),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: a.color, shape: BoxShape.circle),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
