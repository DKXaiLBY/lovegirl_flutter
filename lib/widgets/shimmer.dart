import 'package:flutter/material.dart';

/// 骨架屏扫光占位块（SHIMMER）：高度与真实内容对齐，带扫光渐变位移
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius radius;

  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = const BorderRadius.all(Radius.circular(10)),
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _ShimmerPainter(t: _ctrl.value, radius: widget.radius),
        );
      },
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double t;
  final BorderRadius radius;

  _ShimmerPainter({required this.t, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndCorners(
      Offset.zero & size,
      topLeft: radius.topLeft,
      topRight: radius.topRight,
      bottomLeft: radius.bottomLeft,
      bottomRight: radius.bottomRight,
    );
    canvas.drawRRect(rrect, Paint()..color = Colors.black.withAlpha(14));
    // 扫光带
    final band = size.width * 0.6;
    final dx = -band + (size.width + band * 2) * t;
    final rect = Rect.fromLTWH(dx, 0, band, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withAlpha(0),
          Colors.white.withAlpha(60),
          Colors.white.withAlpha(0),
        ],
      ).createShader(rect);
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShimmerPainter oldDelegate) => oldDelegate.t != t;
}

/// 列表加载骨架（高度按真实内容设计，避免落位跳动）
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget card(double height) => Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: 120, height: 18),
              const SizedBox(height: 12),
              ShimmerBox(height: 54),
              const SizedBox(height: 10),
              ShimmerBox(width: 200, height: 14),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: Column(
        children: [
          ShimmerBox(height: 46, radius: BorderRadius.circular(16)),
          const SizedBox(height: 18),
          card(180),
          card(150),
          card(150),
        ],
      ),
    );
  }
}
