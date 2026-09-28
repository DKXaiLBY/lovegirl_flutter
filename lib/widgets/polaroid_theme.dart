import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 拍立得四主题（v3.38，参考图 docs/design/refs 第二批 7 张 1:1 还原）：
/// classic 经典白框+手写日期 / tape 黑胶带卡（BACK 字母带+白字）/
/// film 暗色胶片黑卡（橙色小字）/ letter 红字白卡（DATE/PLACE 栏目+BACK4U）
enum PolaroidTheme { classic, tape, film, letter }

/// 相框渲染样式包
class PolaroidStyle {
  final Color frameColor;
  final EdgeInsets framePadding;
  final Color captionColor;
  final Color backColor;
  final Color backTextColor;
  final Widget? topDecor;

  /// 顶部装饰条总占高（含下间距）——必须计入高度预算，否则 Column 溢出
  final double topDecorHeight;

  const PolaroidStyle({
    required this.frameColor,
    required this.framePadding,
    required this.captionColor,
    required this.backColor,
    required this.backTextColor,
    this.topDecor,
    this.topDecorHeight = 0,
  });
}

extension PolaroidThemeX on PolaroidTheme {
  static PolaroidTheme fromName(String name) =>
      PolaroidTheme.values.firstWhere(
        (t) => t.name == name,
        orElse: () => PolaroidTheme.classic,
      );

  /// 相框渲染样式包（底色/内边距/文字色/装饰条）——命名避开 enum.name
  PolaroidStyle get style {
    switch (this) {
      case PolaroidTheme.classic:
        return PolaroidStyle(
          frameColor: const Color(0xFFFFFFFF),
          framePadding: const EdgeInsets.fromLTRB(10, 10, 10, 46),
          captionColor: const Color(0xFF2B2B2E),
          backColor: const Color(0xFFEFEAE2),
          backTextColor: const Color(0xFF3A3A3C),
        );
      case PolaroidTheme.tape:
        return PolaroidStyle(
          frameColor: const Color(0xFF2B2B2E),
          framePadding: const EdgeInsets.fromLTRB(10, 0, 10, 46),
          captionColor: const Color(0xFFECECEE),
          backColor: const Color(0xFF1C1C1E),
          backTextColor: const Color(0xFFD8D8DC),
          topDecor: const _BackTapeStrip(),
          topDecorHeight: 30,
        );
      case PolaroidTheme.film:
        return PolaroidStyle(
          frameColor: const Color(0xFF161618),
          framePadding: const EdgeInsets.fromLTRB(10, 0, 10, 46),
          captionColor: const Color(0xFFE8A25D),
          backColor: const Color(0xFF101012),
          backTextColor: const Color(0xFFD8D8DC),
          topDecor: const _FilmSprocketStrip(),
          topDecorHeight: 22,
        );
      case PolaroidTheme.letter:
        return PolaroidStyle(
          frameColor: const Color(0xFFFDFCFA),
          framePadding: const EdgeInsets.fromLTRB(12, 12, 12, 52),
          captionColor: const Color(0xFFC0453E),
          backColor: const Color(0xFFF7F4EE),
          backTextColor: const Color(0xFF8A6E68),
        );
    }
  }

  String get label => switch (this) {
        PolaroidTheme.classic => '经典白框',
        PolaroidTheme.tape => '黑胶带',
        PolaroidTheme.film => '暗色胶片',
        PolaroidTheme.letter => '红字信笺',
      };
}

/// tape 主题顶部：BACK 字母胶带条（参考图 1:1）
class _BackTapeStrip extends StatelessWidget {
  const _BackTapeStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      color: const Color(0xFF0F0F10),
      alignment: Alignment.center,
      child: const Text(
        'BACK  ·  BACK  ·  BACK  ·  BACK  ·  BACK  ·  BACK',
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(
          fontSize: 9,
          letterSpacing: 2,
          color: Color(0xFFB9B9BF),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// film 主题顶部：胶片齿孔示意条
class _FilmSprocketStrip extends StatelessWidget {
  const _FilmSprocketStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 14,
      color: const Color(0xFF0C0C0D),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < 14; i++)
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: const Color(0xFF2E2E31),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

/// 手写风格日期戳（"2/24 24" 形态：日/月 + 两位年，模拟马克笔手写）。
/// 复用 Caveat 手写字体（pubspec 已有 400/700）。
class HandwrittenDate extends StatelessWidget {
  final DateTime date;
  final Color color;
  final double fontSize;

  const HandwrittenDate({
    super.key,
    required this.date,
    required this.color,
    this.fontSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    final text = '${date.day}/${date.month} ${date.year % 100}';
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Caveat',
        fontSize: fontSize,
        height: 1.0,
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// 涂鸦/手写画布数据（背卡涂鸦与白框手写共用笔迹引擎，决策：用户拍板 C4 用涂鸦笔）
class InkStroke {
  final List<Offset> points;
  final double width;
  final Color color;

  const InkStroke({
    required this.points,
    this.width = 2.2,
    this.color = const Color(0xFF2B2B2E),
  });

  Map<String, dynamic> toJson(String Function(Offset) enc, Offset Function(String) dec) => {
        'w': width,
        'c': color.toARGB32Safe(),
        'p': points.map(enc).toList(),
      };

  static InkStroke fromJson(
      Map<String, dynamic> j, Offset Function(String) dec) {
    return InkStroke(
      width: (j['w'] as num?)?.toDouble() ?? 2.2,
      color: Color((j['c'] as num?)?.toInt() ?? 0xFF2B2B2E),
      points: ((j['p'] as List?) ?? const [])
          .map((e) => dec(e.toString()))
          .toList(),
    );
  }

  /// 紧凑序列化：点编码 "x,y"（相对归一化 0-1000，避免浮点串过长）
  static String encodePoint(Offset o) =>
      '${(o.dx * 1000).round()},${(o.dy * 1000).round()}';

  static Offset decodePoint(String s) {
    final parts = s.split(',');
    return Offset(
      (double.tryParse(parts[0]) ?? 0) / 1000,
      (double.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0) / 1000,
    );
  }
}

extension _ColorX on Color {
  /// 兼容 Flutter 3.27（无 toARGB32）
  int toARGB32Safe() => (a * 255).round() << 24 | (r * 255).round() << 16 |
      (g * 255).round() << 8 | (b * 255).round();
}

/// 笔迹画布：手势采集 → 自绘。归一化坐标（0-1），与尺寸解耦。
/// enabled=false 时忽略手势（不阻塞父级滚动）。
class InkCanvas extends StatefulWidget {
  final List<InkStroke> strokes;
  final ValueChanged<List<InkStroke>> onChanged;
  final Color defaultColor;
  final double strokeWidth;
  final bool enabled;

  const InkCanvas({
    super.key,
    required this.strokes,
    required this.onChanged,
    this.defaultColor = const Color(0xFF2B2B2E),
    this.strokeWidth = 2.2,
    this.enabled = true,
  });

  @override
  State<InkCanvas> createState() => _InkCanvasState();
}

class _InkCanvasState extends State<InkCanvas> {
  List<InkStroke> _live = [];
  Offset? _last;

  @override
  void didUpdateWidget(covariant InkCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.strokes != oldWidget.strokes) _live = List.of(widget.strokes);
  }

  void _onDrag(DragUpdateDetails d) {
    final box = context.findRenderObject() as RenderBox;
    final pos = box.globalToLocal(d.globalPosition);
    final size = box.size;
    final norm = Offset(pos.dx / size.width, pos.dy / size.height);
    if (_last == null) {
      _live.add(InkStroke(
        points: [norm],
        width: widget.strokeWidth,
        color: widget.defaultColor,
      ));
    } else {
      final s = _live.removeLast();
      _live.add(InkStroke(
        points: [...s.points, norm],
        width: s.width,
        color: s.color,
      ));
    }
    _last = norm;
    widget.onChanged(List.of(_live));
  }

  void _onDragEnd(DragEndDetails d) => _last = null;

  @override
  Widget build(BuildContext context) {
    final canvas = CustomPaint(
      painter: _InkPainter(strokes: _live),
      child: const SizedBox.expand(),
    );
    if (!widget.enabled) {
      return IgnorePointer(child: canvas);
    }
    return GestureDetector(
      onPanUpdate: _onDrag,
      onPanEnd: _onDragEnd,
      child: canvas,
    );
  }
}

class _InkPainter extends CustomPainter {
  final List<InkStroke> strokes;
  const _InkPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final s in strokes) {
      if (s.points.isEmpty) continue;
      paint
        ..color = s.color
        ..strokeWidth = s.width;
      final path = Path()
        ..moveTo(s.points.first.dx * size.width, s.points.first.dy * size.height);
      for (final p in s.points.skip(1)) {
        path.lineTo(p.dx * size.width, p.dy * size.height);
      }
      // 平滑：二次贝塞尔中点法
      final smooth = Path();
      final pts = s.points;
      smooth.moveTo(pts[0].dx * size.width, pts[0].dy * size.height);
      if (pts.length == 2) {
        smooth.lineTo(pts[1].dx * size.width, pts[1].dy * size.height);
      } else {
        for (var i = 1; i < pts.length - 1; i++) {
          final mid = Offset(
            (pts[i].dx + pts[i + 1].dx) / 2 * size.width,
            (pts[i].dy + pts[i + 1].dy) / 2 * size.height,
          );
          smooth.quadraticBezierTo(
              pts[i].dx * size.width, pts[i].dy * size.height, mid.dx, mid.dy);
        }
        final last = pts.last;
        smooth.lineTo(last.dx * size.width, last.dy * size.height);
      }
      canvas.drawPath(smooth, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _InkPainter oldDelegate) =>
      oldDelegate.strokes != strokes;
}

/// math 导出占位（未来旋转笔迹用）
const kInkEpsilon = math.pi / 180;
