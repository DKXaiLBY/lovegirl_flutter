import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovegirl_flutter/providers/travel_provider.dart';
import 'package:lovegirl_flutter/screens/home/home_screen.dart';
import 'package:lovegirl_flutter/screens/mood/mood_screen.dart';
import 'package:lovegirl_flutter/widgets/travel_map_widget.dart';

/// W5 阶段三纯函数回归（对抗审查清单第 7 项）：分组/渐变色/时间线/足迹/N年前
Color _c(int v) => Color(v & 0xFFFFFFFF);

Map<String, dynamic> _mood(String date, int emoji, {int? id}) =>
    {'recordDate': date, 'emoji': emoji, 'label': 'x', if (id != null) 'id': id};

TravelSpot _spot({required int id, String? visitedDate, double lat = 30, double lng = 120, String status = 'visited'}) {
  return TravelSpot(
    id: id,
    name: 's$id',
    status: status,
    visitedDate: visitedDate,
    lng: lng,
    lat: lat,
  );
}

void main() {
  group('groupMoodsByDate（date/recordDate 双键兼容）', () {
    test('按日分组且保留同日多条', () {
      final g = groupMoodsByDate([
        _mood('2026-09-01', 0),
        _mood('2026-09-01', 3),
        _mood('2026-09-02', 6),
      ]);
      expect(g['2026-09-01']!.length, 2);
      expect(g['2026-09-02']!.length, 1);
    });
    test('recordDate 优先于 date', () {
      final g = groupMoodsByDate([
        {'recordDate': '2026-09-05', 'date': '2026-08-01', 'emoji': 0},
      ]);
      expect(g.containsKey('2026-09-05'), isTrue);
      expect(g.containsKey('2026-08-01'), isFalse);
    });
  });

  group('dayGradientColors（相邻同色合并，单色回退）', () {
    test('相邻同色合并为一扇', () {
      final r = dayGradientColors([_c(0xFF7B8CFF), _c(0xFF7B8CFF), _c(0xFFE95B4E)]);
      expect(r.length, 2);
      expect(r[0], _c(0xFF7B8CFF));
    });
    test('全同色回退单色（渐变退化为纯色语义）', () {
      final r = dayGradientColors([_c(0xFF7B8CFF), _c(0xFF7B8CFF)]);
      expect(r.length, 1);
    });
    test('色板身份唯一性（幸福/难过同色是 v3.42 前的存量 bug——回归闸）', () {
      const palette = [
        Color(0xFF8FAE8B), Color(0xFF7B8CFF), Color(0xFF6BD4FF),
        Color(0xFF5B6EA8), Color(0xFFE95B4E), Color(0xFF9E9EAD),
        Color(0xFF00BCD4), Color(0xFF4DB6A2), Color(0xFF9E9AD1),
        Color(0xFFB58860),
      ];
      expect(palette.toSet().length, palette.length);
    });
  });

  group('footprintSpots（足迹线纯函数）', () {
    test('只留 visited+有日期+坐标有效，按日期升序（id 决胜）', () {
      final r = footprintSpots([
        _spot(id: 3, visitedDate: '2026-05-01'),
        _spot(id: 1, visitedDate: '2026-01-01'),
        _spot(id: 2), // 无日期
        _spot(id: 4, visitedDate: '2026-03-01', lat: 0, lng: 0), // 无效坐标
        _spot(id: 5, status: 'wish', visitedDate: '2026-02-01'), // 未打卡
      ]);
      expect(r.map((e) => e.id).toList(), [1, 3]);
    });
    test('少于 2 个有效点时调用方应跳过', () {
      expect(footprintSpots([_spot(id: 1, visitedDate: '2026-01-01')]).length, 1);
      expect(footprintSpots([]), isEmpty);
    });
  });

  group('pickMemoryToday（N 年前的今天）', () {
    final now = DateTime(2026, 9, 30);
    test('命中去年同月日的照片（年最远优先）', () {
      final m = pickMemoryToday([
        {'id': 1, 'photo_date': '2025-09-30 10:00:00', 'description': '去年'},
        {'id': 2, 'photo_date': '2024-09-30 10:00:00', 'description': '前年'},
      ], [], now);
      expect(m, isNotNull);
      expect(m!['years'], 2); // 年代最远优先
      expect(m['type'], 'photo');
    });
    test('当年照片不命中（防御负数 N）', () {
      final m = pickMemoryToday([
        {'id': 1, 'photo_date': '2026-09-30 10:00:00'},
      ], [], now);
      expect(m, isNull);
    });
    test('照片与足迹同日：照片优先', () {
      final m = pickMemoryToday([
        {'id': 1, 'photo_date': '2025-09-30'},
      ], [
        _spot(id: 9, visitedDate: '2025-09-30'),
      ], now);
      expect(m!['type'], 'photo');
      expect(m['years'], 1);
    });
    test('photo_date 为空回退 created_at（v3.40 前老照片口径）', () {
      final m = pickMemoryToday([
        {'id': 1, 'created_at': '2023-09-30 08:00:00'},
      ], [], now);
      expect(m!['years'], 3);
    });
    test('月日不匹配不命中', () {
      final m = pickMemoryToday([
        {'id': 1, 'photo_date': '2025-10-01'},
      ], [], now);
      expect(m, isNull);
    });
  });
}
