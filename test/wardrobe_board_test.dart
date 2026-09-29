import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lovegirl_flutter/models/wardrobe.dart';

/// 换装白板 W1 纯函数回归：槽位归类 / 互斥矩阵 / 预设锚点 / 位置记忆解析
void main() {
  const allCategories = [
    '上装', '裤装', '裙装', '外套', '鞋子', '包袋', '配饰', '连体装'
  ];

  group('白板槽位归类', () {
    test('八类目全部有槽位', () {
      for (final c in allCategories) {
        expect(wardrobeSlotOf(c), isNotEmpty, reason: c);
      }
    });

    test('连体装并入上身组（P1-3：托盘必须有容身处）', () {
      expect(wardrobeSlotOf('上装'), '上身');
      expect(wardrobeSlotOf('连体装'), '上身');
      expect(wardrobeSlotOf('裤装'), '下身');
      expect(wardrobeSlotOf('裙装'), '下身');
    });

    test('z 序：下身 < 上身 < 外套 < 鞋 < 包 < 配饰', () {
      final zs =
          ['裤装', '上装', '外套', '鞋子', '包袋', '配饰'].map(wardrobeZOf).toList();
      final sorted = List.of(zs)..sort();
      expect(zs, orderedEquals(sorted));
    });
  });

  group('互斥矩阵（interaction §P13 口径）', () {
    test('上装⇄连体；裤⇄裙；连体清上身+下身', () {
      expect(wardrobeConflictsOf('上装'), contains('连体装'));
      expect(wardrobeConflictsOf('连体装'),
          containsAll(['上装', '裤装', '裙装']));
      expect(wardrobeConflictsOf('裤装'), containsAll(['裙装', '连体装']));
      expect(wardrobeConflictsOf('裙装'), containsAll(['裤装', '连体装']));
    });

    test('外套/鞋/包/配饰无互斥', () {
      for (final c in ['外套', '鞋子', '包袋', '配饰']) {
        expect(wardrobeConflictsOf(c), isEmpty, reason: c);
      }
    });
  });

  group('预设锚点', () {
    test('八类目全覆盖且数值在界内', () {
      for (final c in allCategories) {
        final a = wardrobePresetAnchors[c];
        expect(a, isNotNull, reason: c);
        expect(a!.$1, inInclusiveRange(0, 1));
        expect(a.$2, inInclusiveRange(0, 1));
        expect(a.$3, inInclusiveRange(0.1, 0.9));
      }
    });
  });

  group('WardrobeItemLayout.parse（mysql2 JSON 列返回对象，Map-first）', () {
    test('Map 形态（生产主路径）', () {
      final m = WardrobeItemLayout.parse({
        '42': {'nx': 0.5, 'ny': 0.32, 'scale': 0.55},
      });
      expect(m, isNotNull);
      expect(m!['42']!.nx, 0.5);
      expect(m['42']!.scale, 0.55);
    });

    test('字符串形态兜底', () {
      final m = WardrobeItemLayout.parse(
          jsonEncode({'7': {'nx': 1, 'ny': 2, 'scale': 3}}));
      expect(m, isNotNull);
      expect(m!['7']!.ny, 2.0);
    });

    test('坏数据返回 null、坏 entry 丢弃', () {
      expect(WardrobeItemLayout.parse('not json'), isNull);
      expect(WardrobeItemLayout.parse(123), isNull);
      expect(WardrobeItemLayout.parse(null), isNull);
      final m = WardrobeItemLayout.parse({
        '1': {'nx': 'x'},
        '2': {'nx': 0.1, 'ny': 0.2, 'scale': 0.3},
      });
      expect(m!.containsKey('1'), isFalse);
      expect(m.containsKey('2'), isTrue);
    });
  });

  group('WardrobeItem.copyWith 位置记忆（P1-5 内存回写用）', () {
    test('只换 itemLayout 其余字段保持、原对象不变', () {
      final it = const WardrobeItem(
        id: 1,
        imageUrl: '/a.jpg',
        category: '上装',
        status: '在柜',
        bgRemoved: true,
        cutoutUrl: '/c.png',
      );
      final l = {'9': const WardrobeItemLayout(nx: 0.4, ny: 0.4, scale: 0.5)};
      final c = it.copyWith(itemLayout: l);
      expect(c.id, 1);
      expect(c.cutoutUrl, '/c.png');
      expect(c.hasCutout, isTrue);
      expect(c.itemLayout!['9']!.nx, 0.4);
      expect(it.itemLayout, isNull);
    });
  });
}
