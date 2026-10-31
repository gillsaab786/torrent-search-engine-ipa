import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../appearance.dart';

OverlayEntry? _current;
Timer? _timer;

/// Short message shown above everything, including bottom sheets.
void showToast(BuildContext context, String message, {IconData icon = CupertinoIcons.checkmark_alt_circle_fill}) {
  HapticFeedback.lightImpact();
  final overlay = Overlay.of(context, rootOverlay: true);
  final accent = Theme.of(context).colorScheme.primary;
  _timer?.cancel();
  _current?.remove();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: 24,
      right: 24,
      top: MediaQuery.of(context).padding.top + 12,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 180),
          builder: (_, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, -12 * (1 - t)), child: child),
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Ios.fill,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: accent, size: 22),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(message,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                ),
              ]),
            ),
          ),
        ),
      ),
    ),
  );
  _current = entry;
  overlay.insert(entry);
  _timer = Timer(const Duration(milliseconds: 1800), () {
    if (_current == entry) {
      entry.remove();
      _current = null;
    }
  });
}
