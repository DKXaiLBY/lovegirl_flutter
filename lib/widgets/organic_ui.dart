import 'dart:math';
import 'package:flutter/material.dart';

/// 有机形态绘制工具类
class OrganicPaths {
  /// 生成波浪顶部路径
  static Path wavyTop(Rect rect, {int waves = 4, double amplitude = 12}) {
    final path = Path();
    path.moveTo(rect.left, rect.top);
    final waveWidth = rect.width / waves;
    for (int i = 0; i < waves; i++) {
      final x1 = rect.left + waveWidth * (i + 0.25);
      final y1 = rect.top + (i.isEven ? -amplitude : amplitude);
      final x2 = rect.left + waveWidth * (i + 0.75);
      final y2 = rect.top + (i.isEven ? amplitude : -amplitude);
      final x3 = rect.left + waveWidth * (i + 1);
      path.cubicTo(x1, y1, x2, y2, x3, rect.top);
    }
    path.lineTo(rect.right, rect.top);
    path.lineTo(rect.right, rect.bottom);
    path.lineTo(rect.left, rect.bottom);
    path.close();
    return path;
  }

  /// 生成随机有机 blob 形状
  static Path randomBlob(Rect rect, {int points = 8, double variance = 0.3}) {
    final rand = Random(42);
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final rx = rect.width / 2;
    final ry = rect.height / 2;
    final path = Path();

    for (int i = 0; i < points; i++) {
      final angle = (2 * pi * i) / points;
      final nextAngle = (2 * pi * (i + 1)) / points;
      final r = 1.0 + (rand.nextDouble() - 0.5) * variance * 2;
      final x = cx + rx * r * cos(angle);
      final y = cy + ry * r * sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final cpx = cx + rx * r * cos(angle + (nextAngle - angle) * 0.3);
        final cpy = cy + ry * r * sin(angle + (nextAngle - angle) * 0.3);
        path.quadraticBezierTo(cpx, cpy, x, y);
      }
    }
    path.close();
    return path;
  }

  /// 生成底部波浪曲线
  static Path wavyBottom(Rect rect, {int waves = 5, double amplitude = 15}) {
    final path = Path();
    path.moveTo(rect.left, rect.top);
    path.lineTo(rect.right, rect.top);
    path.lineTo(rect.right, rect.bottom);

    final waveWidth = rect.width / waves;
    for (int i = 0; i < waves; i++) {
      final x1 = rect.right - waveWidth * (i + 0.25);
      final y1 = rect.bottom + (i.isEven ? -amplitude : amplitude);
      final x2 = rect.right - waveWidth * (i + 0.75);
      final y2 = rect.bottom + (i.isEven ? amplitude : -amplitude);
      final x3 = rect.right - waveWidth * (i + 1);
      path.cubicTo(x1, y1, x2, y2, x3, rect.bottom);
    }
    path.close();
    return path;
  }

  /// 生成手绘矩形（微抖动边缘）
  static Path handDrawnRect(Rect rect, {double jitter = 1.5}) {
    final path = Path();
    final rand = Random(rect.left.toInt() + rect.top.toInt());

    path.moveTo(
        rect.left + _jitter(rand, jitter), rect.top + _jitter(rand, jitter));
    _jitterLineTo(path, rand, rect.right, rect.top, jitter);
    _jitterLineTo(path, rand, rect.right, rect.bottom, jitter);
    _jitterLineTo(path, rand, rect.left, rect.bottom, jitter);
    _jitterLineTo(path, rand, rect.left, rect.top, jitter);
    path.close();
    return path;
  }

  static double _jitter(Random rand, double amount) =>
      (rand.nextDouble() - 0.5) * amount * 2;

  static void _jitterLineTo(
      Path path, Random rand, double x, double y, double j) {
    final cx = (path.getBounds().center.dx + x) / 2 + _jitter(rand, j);
    final cy = (path.getBounds().center.dy + y) / 2 + _jitter(rand, j);
    path.quadraticBezierTo(cx, cy, x + _jitter(rand, j), y + _jitter(rand, j));
  }
}

/// 有机形态卡片（自定义绘制）
class OrganicCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final List<Color>? gradient;
  final double borderRadius;
  final bool organic;
  final double height;
  final double width;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? boxShadow;

  const OrganicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.gradient,
    this.borderRadius = 20,
    this.organic = false,
    this.height = 0,
    this.width = 0,
    this.margin,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: width > 0 ? width : null,
      height: height > 0 ? height : null,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withAlpha(240),
        gradient: gradient != null
            ? LinearGradient(
                colors: gradient!,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)
            : null,
        borderRadius: organic ? null : BorderRadius.circular(borderRadius),
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
      ),
      child: child,
    );

    if (!organic) return card;

    return ClipPath(
      clipper: OrganicClipper(borderRadius: borderRadius),
      child: card,
    );
  }
}

class OrganicClipper extends CustomClipper<Path> {
  final double borderRadius;
  OrganicClipper({this.borderRadius = 20});

  @override
  Path getClip(Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rand = Random(rect.width.toInt());
    final path = Path();
    final r = borderRadius;
    final j = 2.0;

    // 左上角
    path.moveTo(0, r);
    path.quadraticBezierTo(
      0 + _j(rand, j),
      0 + _j(rand, j),
      r + _j(rand, j),
      0 + _j(rand, j),
    );
    // 上边
    path.lineTo(size.width - r, 0);
    // 右上角
    path.quadraticBezierTo(
      size.width + _j(rand, j),
      0 + _j(rand, j),
      size.width,
      r,
    );
    // 右边
    path.lineTo(size.width, size.height - r);
    // 右下角
    path.quadraticBezierTo(
      size.width + _j(rand, j),
      size.height + _j(rand, j),
      size.width - r,
      size.height,
    );
    // 下边
    path.lineTo(r, size.height);
    // 左下角
    path.quadraticBezierTo(
      0 + _j(rand, j),
      size.height + _j(rand, j),
      0,
      size.height - r,
    );
    path.close();
    return path;
  }

  double _j(Random r, double a) => (r.nextDouble() - 0.5) * a * 2;

  @override
  bool shouldReclip(covariant OrganicClipper oldClipper) =>
      oldClipper.borderRadius != borderRadius;
}

/// 顶部有机圆角裁剪（用于底部弹窗等）
class TopOrganicClipper extends CustomClipper<Path> {
  final double radius;
  TopOrganicClipper({this.radius = 24});

  @override
  Path getClip(Size size) {
    final path = Path();
    final r = radius;
    final j = 2.0;
    final rand = Random(1);
    path.moveTo(0, size.height);
    path.lineTo(0, r);
    path.quadraticBezierTo(
      0 + _j2(rand, j),
      0 + _j2(rand, j),
      r + _j2(rand, j),
      0 + _j2(rand, j),
    );
    path.lineTo(size.width - r, 0);
    path.quadraticBezierTo(
      size.width + _j2(rand, j),
      0 + _j2(rand, j),
      size.width,
      r,
    );
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  double _j2(Random r, double a) => (r.nextDouble() - 0.5) * a * 2;

  @override
  bool shouldReclip(covariant TopOrganicClipper oldClipper) =>
      oldClipper.radius != radius;
}

/// 波浪背景容器
class WavyBackground extends StatelessWidget {
  final Widget child;
  final List<Color> colors;
  final Alignment begin;
  final Alignment end;

  const WavyBackground({
    super.key,
    required this.child,
    this.colors = const [Color(0xFF635BFF), Color(0xFF00D4AA)],
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: begin, end: end),
      ),
      child: ClipPath(
        clipper: _WavyBottomClipper(),
        child: child,
      ),
    );
  }
}

class _WavyBottomClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height - 30);

    // 底部波浪
    final waveCount = 4;
    final waveWidth = size.width / waveCount;
    for (int i = 0; i < waveCount; i++) {
      final x1 = size.width - waveWidth * (i + 0.25);
      final y1 = size.height - 30 + (i.isEven ? -20 : 20);
      final x2 = size.width - waveWidth * (i + 0.75);
      final y2 = size.height - 30 + (i.isEven ? 20 : -20);
      final x3 = size.width - waveWidth * (i + 1);
      path.cubicTo(x1, y1, x2, y2, x3, size.height - 30);
    }
    path.lineTo(0, size.height - 30);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _WavyBottomClipper old) => false;
}

/// 噪点纹理覆盖层
class NoiseOverlay extends StatelessWidget {
  final double opacity;
  final Color color;

  const NoiseOverlay(
      {super.key, this.opacity = 0.03, this.color = Colors.black});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _NoisePainter(opacity: opacity, color: color),
        ),
      ),
    );
  }
}

class _NoisePainter extends CustomPainter {
  final double opacity;
  final Color color;

  _NoisePainter({required this.opacity, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withAlpha((opacity * 255).round());
    final rand = Random(42);

    for (int i = 0; i < 200; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final r = rand.nextDouble() * 2 + 0.5;
      final alpha = (rand.nextDouble() * 255).round();
      paint.color = color.withAlpha((alpha * opacity).round());
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NoisePainter old) =>
      old.opacity != opacity || old.color != color;
}

/// 随机有机 Blob 装饰
class BlobDecoration extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  final Alignment alignment;

  const BlobDecoration({
    super.key,
    this.size = 200,
    this.color = const Color(0xFF635BFF),
    this.opacity = 0.1,
    this.alignment = Alignment.topRight,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: CustomPaint(
        size: Size(size, size),
        painter: _BlobPainter(color: color, opacity: opacity),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  final Color color;
  final double opacity;

  _BlobPainter({required this.color, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha((opacity * 255).round())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);

    final path = OrganicPaths.randomBlob(
      Rect.fromLTWH(0, 0, size.width, size.height),
      points: 10,
      variance: 0.4,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BlobPainter old) =>
      old.color != color || old.opacity != opacity;
}

/// 渐变光晕层（Aurora 效果）
class AuroraBackground extends StatefulWidget {
  final Widget child;
  final List<Color> colors;

  const AuroraBackground({
    super.key,
    required this.child,
    this.colors = const [
      Color(0xFF635BFF),
      Color(0xFF00D4AA),
      Color(0xFFFF6B8A)
    ],
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            // 动态光晕层
            Positioned.fill(
              child: CustomPaint(
                painter: _AuroraPainter(
                  colors: widget.colors,
                  progress: _controller.value,
                ),
              ),
            ),
            // 内容层
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final List<Color> colors;
  final double progress;

  _AuroraPainter({required this.colors, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < colors.length; i++) {
      final paint = Paint()
        ..color = colors[i].withAlpha(25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

      final offsetX =
          size.width * (0.3 + 0.4 * sin(progress * 2 * pi + i * 2.0));
      final offsetY =
          size.height * (0.3 + 0.4 * cos(progress * 2 * pi + i * 1.5));

      canvas.drawCircle(
        Offset(offsetX, offsetY),
        size.width * 0.4,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) => old.progress != progress;
}
