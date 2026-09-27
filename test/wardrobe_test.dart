import 'package:flutter_test/flutter_test.dart';
import 'package:lovegirl_flutter/models/wardrobe.dart';

void main() {
  group('WardrobeItem.fromJson', () {
    test('完整字段解析', () {
      final it = WardrobeItem.fromJson({
        'id': 3,
        'image_url': '/uploads/wardrobe/a.jpg',
        'thumbnail_url': '/uploads/wardrobe/a_thumb.webp',
        'category': '上装',
        'temperature': '凉爽',
        'occasions': ['日常', '约会'],
        'styles': ['简约'],
        'color': '黑白灰',
        'brand': 'Uniqlo',
        'price': 199.5,
        'status': '在柜',
        'wear_count': 2,
        'outfit_refs_count': 1,
        'created_at': '2026-09-27T10:00:00.000Z',
      });
      expect(it.id, 3);
      expect(it.category, '上装');
      expect(it.occasions, ['日常', '约会']);
      expect(it.price, 199.5);
      expect(it.retired, isFalse);
      expect(it.wearCount, 2);
      expect(it.refCount, 1);
    });

    test('退役态与缺省字段', () {
      final it = WardrobeItem.fromJson({
        'id': 1,
        'image_url': '/x.jpg',
        'category': '鞋',
        'status': '退役',
      });
      expect(it.retired, isTrue);
      expect(it.occasions, isEmpty);
      expect(it.wearCount, 0);
    });
  });

  group('WardrobeOutfit.fromJson', () {
    test('组合+摘要解析（含软删占位）', () {
      final o = WardrobeOutfit.fromJson({
        'id': 7,
        'worn_date': '2026-10-01T00:00:00.000Z',
        'source': '组合',
        'itemIds': [1, 2],
        'items': [
          {
            'id': 1,
            'deleted': true,
            'category': '上装',
            'brand': null,
            'thumbnailUrl': null,
          },
          {
            'id': 2,
            'deleted': false,
            'category': '裤装',
            'brand': 'A',
            'thumbnailUrl': '/t.webp',
          },
        ],
        'status': '待确认',
        'note': '约会穿',
      });
      expect(o.isCombo, isTrue);
      expect(o.approved, isFalse);
      expect(o.itemIds, [1, 2]);
      expect(o.items.length, 2);
      expect(o.items[0].deleted, isTrue);
      expect(o.items[0].category, '上装');
      expect(o.items[1].deleted, isFalse);
      // 2026-10-01 相对今天（2026-09-27）是未来 → 计划
      expect(o.isPlanned('2026-09-27'), isTrue);
      expect(o.isPlanned('2026-10-02'), isFalse);
    });
  });

  group('groupOutfits 时间线分组', () {
    WardrobeOutfit o(String date, int id) => WardrobeOutfit(
          id: id,
          wornDate: date,
          source: '组合',
          status: '待确认',
        );

    test('计划中/今天/昨天/本周更早/更早 + 计划按日期升序', () {
      // 2026-09-27 是周日：本周一 = 09-21
      final now = DateTime(2026, 9, 27, 15);
      final outfits = [
        o('2026-09-27', 1), // 今天
        o('2026-09-26', 2), // 昨天
        o('2026-09-23', 3), // 本周更早
        o('2026-09-20', 4), // 更早（上周）
        o('2026-10-05', 5), // 计划（远）
        o('2026-09-29', 6), // 计划（近）
      ];
      final groups = groupOutfits(outfits, now);
      expect(groups.map((g) => g.label).toList(),
          ['计划中', '今天', '昨天', '本周更早', '更早']);
      // 计划中最近优先 = 日期升序
      expect(groups[0].outfits.map((e) => e.id).toList(), [6, 5]);
    });

    test('空列表无分组', () {
      expect(groupOutfits([], DateTime(2026, 9, 27)), isEmpty);
    });
  });

  group('WardrobeTax 温度取档（整数℃无缝隙）', () {
    test('四档边界', () {
      expect(WardrobeTax.tempToBand(35), '炎热');
      expect(WardrobeTax.tempToBand(28), '炎热');
      expect(WardrobeTax.tempToBand(27), '温暖');
      expect(WardrobeTax.tempToBand(20), '温暖');
      expect(WardrobeTax.tempToBand(19), '凉爽');
      expect(WardrobeTax.tempToBand(10), '凉爽');
      expect(WardrobeTax.tempToBand(9), '寒冷');
      expect(WardrobeTax.tempToBand(-5), '寒冷');
    });
  });
}
