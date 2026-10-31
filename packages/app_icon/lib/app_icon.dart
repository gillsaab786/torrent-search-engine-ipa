import 'package:flutter/services.dart';

/// Changes the app's home-screen icon. iOS shows its own confirmation alert.
class AppIcon {
  static const _channel = MethodChannel('app_icon');

  static Future<bool> get supported async {
    try {
      return await _channel.invokeMethod<bool>('supported') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Pass null for the default icon, or an alternate name like "AppIcon-Blue".
  static Future<bool> set(String? name) async {
    try {
      return await _channel.invokeMethod<bool>('set', name) ?? false;
    } catch (_) {
      return false;
    }
  }
}
