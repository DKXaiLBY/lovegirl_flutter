import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 界面动效偏好（持久化）
class MapPrefsProvider extends ChangeNotifier {
  static const _keyMotion = 'motion_level';

  bool _motionEnabled = true;
  bool get motionEnabled => _motionEnabled;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    // The former standard and rich levels both map to enabled.
    _motionEnabled = prefs.getString(_keyMotion) != 'off';
    notifyListeners();
  }

  Future<void> setMotionEnabled(bool value) async {
    _motionEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    // Keep the old storage format so rolling back preserves the setting.
    await prefs.setString(_keyMotion, value ? 'standard' : 'off');
  }
}
