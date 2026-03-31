import 'dart:io' show Platform;
import 'package:flutter/services.dart';

// Minimal macOS window control wrapper via MethodChannel.
// No-ops on non-macOS platforms.
class WindowControl {
  static const _channel = MethodChannel('window_control');

  static bool get _isMacOS => Platform.isMacOS;

  static Future<void> setResizable(bool enabled) async {
    if (!_isMacOS) return;
    try {
      await _channel.invokeMethod('setResizable', {'enabled': enabled});
    } catch (_) {}
  }

  static Future<void> setMinSize(double width, double height) async {
    if (!_isMacOS) return;
    try {
      await _channel.invokeMethod('setMinSize', {'width': width, 'height': height});
    } catch (_) {}
  }

  static Future<void> setContentSize(double width, double height) async {
    if (!_isMacOS) return;
    try {
      await _channel.invokeMethod('setContentSize', {'width': width, 'height': height});
    } catch (_) {}
  }

  // Helpers for our app
  static const double authW = 420;
  static const double authH = 620;
  static const double homeMinW = 1040;
  static const double homeMinH = 720;

  // Keep login/register fixed and non-resizable
  static Future<void> enforceAuthWindow() async {
    await setResizable(false);
    await setContentSize(authW, authH);
    await setMinSize(authW, authH);
  }

  // Enable main window behavior after login
  static Future<void> enableHomeWindow() async {
    await setResizable(true);
    await setMinSize(homeMinW, homeMinH);
    await setContentSize(homeMinW, homeMinH);
  }
}

