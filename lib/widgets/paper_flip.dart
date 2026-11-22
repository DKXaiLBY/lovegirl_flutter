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
    return RepaintBoundary(
        child: LayoutBuilder(builder: (context, constraints) {
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
            // Keep the same perspective rendering path when the sheet is at rest.
            ..rotateY(angle.clamp(.001, math.pi - .001).toDouble());
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
    }));
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
      width: shadowWidth + 10,
      height: size.height * (1 - .11 * lift) + 12,
    );
    // Keep the contact shadow soft without rasterizing a blur on each tick.
    canvas.save();
    canvas.translate(shadow.center.dx, shadow.center.dy);
    canvas.scale(shadow.width / 2, shadow.height / 2);
    canvas.drawCircle(
        Offset.zero,
        1,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.black.withAlpha((61 - 19 * lift).round()),
              Colors.transparent,
            ],
            stops: const [.60, 1],
          ).createShader(const Rect.fromLTRB(-1, -1, 1, 1)));
    canvas.restore();
    if (lift < .02) return;
    final front = turn.clone()..translate(0.0, 0.0, -depth);
    final back = turn.clone()..translate(0.0, 0.0, depth);
    Offset corner(Matrix4 face, double y) =>
        center + MatrixUtils.transformPoint(face, Offset(w, y));
    final edge = Path()
      ..addPolygon([
        corner(front, -h),
        corner(front, h),
        corner(back, h),
        corner(back, -h),
      ], true);
    canvas.drawPath(edge, Paint()..color = const Color(0xffd5cbb9));
  }

  @override
  bool shouldRepaint(_PaperDepth oldDelegate) =>
      oldDelegate.turn != turn || oldDelegate.depth != depth;
}
