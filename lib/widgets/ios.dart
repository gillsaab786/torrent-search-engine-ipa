import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../appearance.dart';

/// Large bold page title, iOS style.
class LargeTitle extends StatelessWidget {
  final String text;
  final List<Widget> actions;
  const LargeTitle(this.text, {super.key, this.actions = const []});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 6),
        child: Row(children: [
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
          ),
          ...actions,
        ]),
      );
}

/// Grouped, rounded section with an uppercase header, like iOS Settings.
class IosSection extends StatelessWidget {
  final String? header;
  final String? footer;
  final List<Widget> children;
  const IosSection({super.key, this.header, this.footer, required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(const Padding(
          padding: EdgeInsets.only(left: 16),
          child: Divider(height: 0.5, thickness: 0.5, color: Ios.separator),
        ));
      }
      rows.add(children[i]);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
            child: Text(header!.toUpperCase(),
                style: const TextStyle(fontSize: 13, color: Ios.secondaryLabel, letterSpacing: 0.2)),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(color: Ios.grouped, child: Column(children: rows)),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
            child: Text(footer!, style: const TextStyle(fontSize: 13, color: Ios.secondaryLabel)),
          ),
      ]),
    );
  }
}

/// One row in an [IosSection]: title, optional subtitle, and a trailing
/// value (shown in the accent colour), switch, or chevron.
class IosRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool chevron;
  final bool destructive;
  const IosRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.leading,
    this.onTap,
    this.chevron = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 50),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
          child: Row(children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 17,
                        color: destructive ? const Color(0xFFFF453A) : Colors.white)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!,
                        style: const TextStyle(fontSize: 13, color: Ios.secondaryLabel)),
                  ),
              ]),
            ),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(value!, style: TextStyle(fontSize: 17, color: accent)),
              ),
            if (trailing != null) Padding(padding: const EdgeInsets.only(left: 8), child: trailing!),
            if (chevron)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(CupertinoIcons.chevron_right, size: 17, color: Ios.tertiaryLabel),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Accent-coloured iOS switch.
class IosSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const IosSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: Theme.of(context).colorScheme.primary,
      );
}

/// Horizontal filter pills: the selected one is filled with the accent.
class PillTabs<T> extends StatelessWidget {
  final List<T> items;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;
  const PillTabs(
      {super.key,
      required this.items,
      required this.selected,
      required this.label,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final it in items)
            GestureDetector(
              onTap: () => onSelected(it),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: it == selected ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label(it),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: it == selected ? onAccent(accent) : Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
