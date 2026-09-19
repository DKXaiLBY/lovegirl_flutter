import 'package:flutter_test/flutter_test.dart';

import 'package:lovegirl_flutter/providers/notification_provider.dart';

void main() {
  group('NotificationItem.fromJson', () {
    test('解析 MySQL datetime 与 Map payload', () {
      final item = NotificationItem.fromJson({
        'id': 7,
        'type': 'kitchen_order',
        'title': '菜做好啦',
        'content': 'TA 完成了你的订单',
        'payload': {'order_id': 12},
        'read_at': null,
        'created_at': '2026-09-20 10:30:00',
      });

      expect(item.id, 7);
      expect(item.type, 'kitchen_order');
      expect(item.payload['order_id'], 12);
      expect(item.isRead, isFalse);
      expect(item.createdAt, DateTime(2026, 9, 20, 10, 30));
    });

    test('已读通知 read_at 正常解析', () {
      final item = NotificationItem.fromJson({
        'id': 8,
        'type': 'travel_checkin',
        'title': 'TA 打卡了一个新地方',
        'content': '广州塔',
        'payload': null,
        'read_at': '2026-09-20 11:00:00',
        'created_at': '2026-09-20 10:30:00',
      });

      expect(item.isRead, isTrue);
      expect(item.readAt, DateTime(2026, 9, 20, 11));
    });

    test('脏数据不崩溃，落到安全默认值', () {
      final item = NotificationItem.fromJson({'id': 'x'});

      expect(item.id, 0);
      expect(item.title, '');
      expect(item.payload, isEmpty);
      expect(item.isToday, isFalse); // epoch 兜底值不是今天，但不抛异常
    });
  });

  group('relativeTime', () {
    final now = DateTime(2026, 9, 20, 12, 0);

    NotificationItem at(DateTime t) => NotificationItem(
          id: 1,
          type: 'kitchen_order',
          title: 't',
          content: 'c',
          createdAt: t,
        );

    test('分钟/小时/昨天/日期分档', () {
      expect(at(now.subtract(const Duration(seconds: 30))).relativeTime(now: now), '刚刚');
      expect(at(now.subtract(const Duration(minutes: 5))).relativeTime(now: now), '5分钟前');
      expect(at(now.subtract(const Duration(hours: 3))).relativeTime(now: now), '3小时前');
      expect(at(now.subtract(const Duration(days: 1))).relativeTime(now: now), '昨天');
      expect(at(DateTime(2026, 9, 16)).relativeTime(now: now), '4天前');
      expect(at(DateTime(2026, 9, 10)).relativeTime(now: now), '09-10');
      expect(at(DateTime(2026, 8, 31)).relativeTime(now: now), '08-31');
      expect(at(DateTime(2025, 12, 31)).relativeTime(now: now), '2025/12-31');
    });

    test('同日跨点（凌晨）不再误报小时前', () {
      // 昨天 23:30 的通知，今天 00:10 查看：跨天必须显示"昨天"
      final created = DateTime(2026, 9, 19, 23, 30);
      final ref = DateTime(2026, 9, 20, 0, 10);
      expect(at(created).relativeTime(now: ref), '昨天');
    });
  });

  test('今天/更早分组', () {
    final now = DateTime.now();
    final today = NotificationItem(
        id: 1, type: 't', title: 'a', content: 'c', createdAt: now);
    final yesterday = NotificationItem(
        id: 2,
        type: 't',
        title: 'b',
        content: 'c',
        createdAt: now.subtract(const Duration(days: 1)));

    expect(today.isToday, isTrue);
    expect(yesterday.isToday, isFalse);
  });
}
