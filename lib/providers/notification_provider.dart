import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

/// 通知中心条目（对应服务器 notifications 表）
class NotificationItem {
  final int id;
  final String type;
  final String title;
  final String content;
  final Map<String, dynamic> payload;
  final DateTime? readAt;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    this.payload = const {},
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    DateTime? tryParse(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      // MySQL datetime 形如 "2026-09-20 02:44:03"，补成 ISO 格式再解析
      return DateTime.tryParse(s.replaceFirst(' ', 'T'));
    }

    Map<String, dynamic> parsePayload(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return v.cast<String, dynamic>();
      return const {};
    }

    return NotificationItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      payload: parsePayload(json['payload']),
      readAt: tryParse(json['read_at']),
      createdAt:
          tryParse(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// 相对时间文案："刚刚 / 5分钟前 / 3小时前 / 昨天 / 09-12"
  String relativeTime({DateTime? now}) {
    final ref = now ?? DateTime.now();
    final diff = ref.difference(createdAt);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24 && ref.day == createdAt.day) return '${diff.inHours}小时前';
    if (diff.inDays == 1) return '昨天';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    final m = createdAt.month.toString().padLeft(2, '0');
    final d = createdAt.day.toString().padLeft(2, '0');
    return '${createdAt.year == ref.year ? '' : '${createdAt.year}/'}$m-$d';
  }

  bool get isToday {
    final now = DateTime.now();
    return createdAt.year == now.year &&
        createdAt.month == now.month &&
        createdAt.day == now.day;
  }
}

/// 通知中心状态：未读角标 + 列表 + 已读操作
class NotificationProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<NotificationItem> items = [];
  int unreadCount = 0;
  bool loading = false;

  /// 首页进入时轻量刷新未读角标；失败静默（角标不是关键路径）
  Future<void> refreshCount() async {
    try {
      final res = await _api.getUnreadNotificationCount();
      final count = (res.data?['data']?['count'] as num?)?.toInt() ?? 0;
      if (count != unreadCount) {
        unreadCount = count;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// 打开通知中心时全量刷新
  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    try {
      final res = await _api.getNotifications();
      final data = res.data?['data'];
      items = (data is List)
          ? data
              .whereType<Map>()
              .map((e) => NotificationItem.fromJson(e.cast<String, dynamic>()))
              .toList()
          : [];
      await refreshCount();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// 点击单条：乐观置已读，失败回滚
  Future<void> markRead(NotificationItem item) async {
    if (item.isRead) return;
    final oldReadAt = item.readAt;
    _applyRead(id: item.id, readAt: DateTime.now());
    try {
      await _api.markNotificationRead(item.id);
    } catch (_) {
      _applyRead(id: item.id, readAt: oldReadAt);
    }
  }

  /// 全部已读
  Future<void> markAllRead() async {
    if (unreadCount == 0 && items.every((e) => e.isRead)) return;
    final snapshot = List<NotificationItem>.from(items);
    final oldCount = unreadCount;
    final now = DateTime.now();
    items = items
        .map((e) => e.isRead ? e : _copyWithRead(e, now))
        .toList();
    unreadCount = 0;
    notifyListeners();
    try {
      await _api.markAllNotificationsRead();
    } catch (_) {
      items = snapshot;
      unreadCount = oldCount;
      notifyListeners();
    }
  }

  void _applyRead({required int id, required DateTime? readAt}) {
    for (var i = 0; i < items.length; i++) {
      if (items[i].id == id) {
        items[i] = _copyWithRead(items[i], readAt);
        break;
      }
    }
    unreadCount = items.where((e) => !e.isRead).length;
    notifyListeners();
  }

  NotificationItem _copyWithRead(NotificationItem src, DateTime? readAt) =>
      NotificationItem(
        id: src.id,
        type: src.type,
        title: src.title,
        content: src.content,
        payload: src.payload,
        readAt: readAt,
        createdAt: src.createdAt,
      );

  List<NotificationItem> get todayItems =>
      items.where((e) => e.isToday).toList();

  List<NotificationItem> get earlierItems =>
      items.where((e) => !e.isToday).toList();
}
