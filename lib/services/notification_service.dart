import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 本地通知服务 — 提醒推送管理
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // 存储key
  static const String _pushEnabledKey = 'push_notification_enabled';
  static const String _pushPeriodKey = 'push_period_enabled';
  static const String _pushAnniversaryKey = 'push_anniversary_enabled';
  static const String _pushTodoKey = 'push_todo_enabled';

  bool get isInitialized => _initialized;

  /// 初始化通知插件
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
    debugPrint('[Notify] 通知服务已初始化');
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('[Notify] 用户点击通知: ${response.payload}');
  }

  /// 检查是否已启用通知总开关
  Future<bool> get isPushEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pushEnabledKey) ?? true;
  }

  /// 设置推送总开关
  Future<void> setPushEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushEnabledKey, enabled);
    if (!enabled) {
      await _plugin.cancelAll();
    }
  }

  /// 显示即时通知
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!await isPushEnabled) return;

    const androidDetails = AndroidNotificationDetails(
      'lovegirl_channel',
      'LoveGirl 提醒',
      channelDescription: '情侣APP重要提醒通知',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details, payload: payload);
  }

  /// 周期性每日通知
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!await isPushEnabled) return;

    const androidDetails = AndroidNotificationDetails(
      'lovegirl_daily_channel',
      'LoveGirl 每日提醒',
      channelDescription: '每日定时提醒',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.periodicallyShow(
      id,
      title,
      body,
      RepeatInterval.daily,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  /// 取消所有通知
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// 取消特定通知
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  /// ========== 业务方法 ==========

  /// 姨妈提醒 — 每日定时推送
  Future<void> schedulePeriodReminder({int daysBefore = 3}) async {
    final enabled = await SharedPreferences.getInstance()
        .then((p) => p.getBool(_pushPeriodKey) ?? true);
    if (!enabled) return;

    await scheduleDailyNotification(
      id: 1001,
      title: '💧 姨妈提醒',
      body: '预计姨妈还有 $daysBefore 天到来，提前做好准备哦~',
      payload: 'health_period',
    );
  }

  /// 纪念日即时提醒（在纪念日当天/临近时由调用方触发）
  Future<void> showAnniversaryReminder({
    required int id,
    required String title,
    int daysUntil = 0,
  }) async {
    final enabled = await SharedPreferences.getInstance()
        .then((p) => p.getBool(_pushAnniversaryKey) ?? true);
    if (!enabled) return;

    if (daysUntil == 0) {
      await showNotification(
        id: 2000 + id,
        title: '🎉 纪念日到了！',
        body: '今天是「$title」！祝你们幸福快乐~',
        payload: 'anniversary_$id',
      );
    } else if (daysUntil <= 3) {
      await showNotification(
        id: 3000 + id,
        title: '💕 纪念日快到了',
        body: '还有$daysUntil天就是「$title」啦！准备惊喜了吗？',
        payload: 'anniversary_$id',
      );
    }
  }

  /// 待办提醒
  Future<void> showTodoReminder({
    required int id,
    required String title,
  }) async {
    final enabled = await SharedPreferences.getInstance()
        .then((p) => p.getBool(_pushTodoKey) ?? true);
    if (!enabled) return;

    await showNotification(
      id: 4000 + id,
      title: '📋 待办提醒',
      body: '「$title」今天到期哦~ 别忘了完成！',
      payload: 'todo_$id',
    );
  }

  // ========== 存储快捷方法（static，方便在设置页直接调用）==========

  static Future<void> setPeriodEnabled(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_pushPeriodKey, v);

  static Future<void> setAnniversaryEnabled(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_pushAnniversaryKey, v);

  static Future<void> setTodoEnabled(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_pushTodoKey, v);
}
