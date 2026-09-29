import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovegirl_flutter/widgets/polaroid_frame.dart';

/// 拍立得立体感纯函数回归（v3.40）：尺寸收缩 / 落影随动 / 厚度侧边 / 动态光泽。
/// 组件视觉层用 matchesGoldenFile 人工比对（生成后即删，不入库——教训 20）。
void main() {
  group('polaroidCardSize 尺寸收缩', () {
    test('宽松约束下保持相纸比例 88:107', () {
      final s = polaroidCardSize(
        const BoxConstraints(maxWidth: 300, maxHeight: 600),
        topDecorHeight: 0,
      );
      expect(s.width, 300);
      expect(s.height, closeTo(300 * 107 / 88, 0.01));
    });

    test('可用高度不足时收缩宽度防溢出', () {
      final s = polaroidCardSize(
        const BoxConstraints(maxWidth: 300, maxHeight: 250),
        topDecorHeight: 0,
      );
      expect(s.width, lessThan(300));
      expect(s.width * 107 / 88, lessThanOrEqualTo(250.01));
    });

    test('同一约束下结果确定（frame 与 tile 阴影层共用不出错位）', () {
      const box = BoxConstraints(maxWidth: 339, maxHeight: 412);
      final a = polaroidCardSize(box, topDecorHeight: 30);
      final b = polaroidCardSize(box, topDecorHeight: 30);
      expect(a, b);
    });

    test('topDecor 越高收缩越多（tape/film 有顶部装饰条）', () {
      const box = BoxConstraints(maxWidth: 339, maxHeight: 412);
      final plain = polaroidCardSize(box, topDecorHeight: 0);
      final taped = polaroidCardSize(box, topDecorHeight: 30);
      expect(taped.width, lessThanOrEqualTo(plain.width));
    });
  });

  group('polaroidCastShadows 落影随动', () {
    test('静置（θ=0）等于静态双层影', () {
      final s = polaroidCastShadows(0);
      expect(s.length, 2);
      expect(s[0].blurRadius, 3);
      expect(s[0].offset, const Offset(0, 2));
      expect(s[0].color.a, closeTo(64 / 255, 0.004));
      expect(s[1].blurRadius, 22);
      expect(s[1].offset, const Offset(0, 12));
    });

    test('翻完（θ=π）回到静置影，无跳变', () {
      final s = polaroidCastShadows(math.pi);
      expect(s[0].blurRadius, 3);
      expect(s[0].offset, const Offset(0, 2));
    });

    test('翻到中段（π/2）影子更大更偏更虚更淡（卡片抬起）', () {
      final s = polaroidCastShadows(math.pi / 2);
      expect(s[0].blurRadius, greaterThan(3));
      expect(s[0].offset.dx, greaterThan(0));
      expect(s[0].offset.dy, greaterThan(2));
      expect(s[0].color.a, lessThan(64 / 255));
    });

    test('换面瞬间（π/2 两侧）影子连续', () {
      final a = polaroidCastShadows(math.pi / 2 - 0.01);
      final b = polaroidCastShadows(math.pi / 2 + 0.01);
      expect(a[0].blurRadius, closeTo(b[0].blurRadius, 0.5));
      expect(a[0].offset.dx, closeTo(b[0].offset.dx, 0.5));
      expect(a[0].offset.dy, closeTo(b[0].offset.dy, 0.5));
    });
  });

  group('厚度侧边', () {
    test('静置无侧边，中段最宽（厚≈1.8% 卡宽），两侧对称', () {
      expect(polaroidEdgeWidth(300, 0), 0);
      expect(polaroidEdgeWidth(300, math.pi), closeTo(0, 1e-9));
      expect(polaroidEdgeWidth(300, math.pi / 2), closeTo(300 * 0.018, 0.01));
      expect(
        polaroidEdgeWidth(300, 0.3),
        closeTo(polaroidEdgeWidth(300, math.pi - 0.3), 0.001),
      );
    });

    test('前半程侧边在右、后半程在左（golden 实测近缘方向）', () {
      expect(polaroidEdgeOnLeft(0.2), isFalse);
      expect(polaroidEdgeOnLeft(math.pi / 2 - 0.01), isFalse);
      expect(polaroidEdgeOnLeft(math.pi / 2 + 0.01), isTrue);
      expect(polaroidEdgeOnLeft(math.pi - 0.2), isTrue);
    });
  });

  group('动态光泽', () {
    test('静置零偏移，前半程正向扫过，中段最大', () {
      expect(polaroidGlossShift(0), 0);
      expect(polaroidGlossShift(math.pi / 4), greaterThan(0));
      expect(polaroidGlossShift(math.pi / 2), closeTo(1, 0.001));
      expect(polaroidGlossShift(math.pi), closeTo(0, 0.001));
    });
  });
}
