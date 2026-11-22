import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppHaptics extends ChangeNotifier {
  static final instance = AppHaptics();
  static const _key = 'interaction_haptics';

  bool _enabled = true;
  bool get enabled => _enabled;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_key) ?? true;
    await _applyToAndroid(_enabled);
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    if (_enabled == enabled) return;
    _enabled = enabled;
    notifyListeners();
    await _applyToAndroid(enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }

  Future<void> _applyToAndroid(bool enabled) async {
    if (!Platform.isAndroid) return;
    try {
      await const MethodChannel('lovegirl/device')
          .invokeMethod<void>('setAppHaptics', enabled);
    } on MissingPluginException {
      return;
    }
  }

  Future<void> _play(Future<void> Function() feedback) async {
    if (_enabled) await feedback();
  }

  Future<void> selectionClick() => _play(HapticFeedback.selectionClick);
  Future<void> lightImpact() => _play(HapticFeedback.lightImpact);
  Future<void> mediumImpact() => _play(HapticFeedback.mediumImpact);
  Future<void> heavyImpact() => _play(HapticFeedback.heavyImpact);
}
