import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 地图与动效偏好（持久化）
class MapPrefsProvider extends ChangeNotifier {
  static const _keyArrows = 'map_show_order_arrows';
  static const _keyMotion = 'motion_level';
  static const _keyFootprints = 'map_show_footprints';

  /// 风格化地图/真地图上按游玩顺序连接地点的箭头线
  bool showOrderArrows = true;

  /// 足迹回忆线：已打卡地点按 visitedDate 升序连成的圆点虚线（W5）
  bool showFootprints = true;

  /// 动效强度：off / standard / rich
  String motionLevel = 'standard';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    showOrderArrows = prefs.getBool(_keyArrows) ?? true;
    showFootprints = prefs.getBool(_keyFootprints) ?? true;
    motionLevel = prefs.getString(_keyMotion) ?? 'standard';
    notifyListeners();
  }

  Future<void> setShowOrderArrows(bool value) async {
    showOrderArrows = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyArrows, value);
  }

  Future<void> setShowFootprints(bool value) async {
    showFootprints = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFootprints, value);
  }

  Future<void> setMotionLevel(String value) async {
    motionLevel = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMotion, value);
  }
}
