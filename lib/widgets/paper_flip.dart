import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'rebuild_controls.dart';

/// The two faces and the cut edge use the same perspective and rotation.
class PaperFlip extends StatelessWidget {
  final bool back;
  final Widget front;
  final Widget reverse;

  const PaperFlip(
      {super.key,
      required this.back,
      required this.front,
      required this.reverse});

  @override
  Widget build(BuildContext context) {
    final still = rebuildReduceMotion(context);
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (width <= 0 || constraints.maxHeight <= 0) return const SizedBox();
      final perspective = .27 / width;
      final depth = (width * .009).clamp(1.0, 2.8);
      return TweenAnimationBuilder<double>(
        tween: Tween(end: back ? math.pi : 0),
        duration: still ? Duration.zero : const Duration(milliseconds: 680),
        curve: Curves.easeInOutSine,
        builder: (context, angle, _) {
          final rear = angle >= math.pi / 2;
          final lift = math.sin(angle).abs();
          final scale = 1 - .13 * lift;
          final turn = Matrix4.identity()
            ..setEntry(3, 2, perspective)
            ..scale(scale, scale, scale)
            ..rotateY(angle);
          return CustomPaint(
            painter: _PaperDepth(turn, depth, lift),
            child: Transform(
              alignment: Alignment.center,
              transformHitTests: false,
              transform: turn.clone()
                ..translate(0.0, 0.0, rear ? depth : -depth)
                ..rotateY(rear ? math.pi : 0),
              child: IndexedStack(
                sizing: StackFit.expand,
                index: rear ? 1 : 0,
                children: [
                  RepaintBoundary(child: front),
                  RepaintBoundary(child: reverse)
                ],
              ),
            ),
          );
        },
      );
    });
  }
}

class _PaperDepth extends CustomPainter {
  final Matrix4 turn;
  final double depth;
  final double lift;
  const _PaperDepth(this.turn, this.depth, this.lift);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final w = center.dx;
    final h = center.dy;
    final shadowWidth = size.width * (1 - .87 * lift);
    final shadow = Rect.fromCenter(
      center: center + Offset(6 * lift, 5 + 12 * lift),
      width: shadowWidth,
      height: size.height * (1 - .11 * lift),
    );
    canvas.drawRRect(
        RRect.fromRectAndRadius(shadow, const Radius.circular(5)),
        Paint()
          ..color = Colors.black.withAlpha((62 - 20 * lift).round())
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 + 6 * lift));
    if (lift < .02) return;
    Offset corner(double y, double z) =>
        center +
        MatrixUtils.transformPoint(
            turn.clone()..translate(0.0, 0.0, z), Offset(w, y));
    final edge = Path()
      ..addPolygon([
        corner(-h, -depth),
        corner(h, -depth),
        corner(h, depth),
        corner(-h, depth),
      ], true);
    canvas.drawPath(edge, Paint()..color = const Color(0xffd5cbb9));
  }

  @override
  bool shouldRepaint(_PaperDepth oldDelegate) =>
      oldDelegate.turn != turn || oldDelegate.depth != depth;
}
