import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/rebuild_controls.dart';
import 'creation_canvas.dart';
import 'creation_catalog.dart';
import 'creation_document.dart';

/// A single object with two readable faces and a projected paper edge.
class CreationPaperTurn extends StatelessWidget {
  final CreationDocument document;
  final bool back;
  final Widget front;
  final double lightShift;
  const CreationPaperTurn({
    super.key,
    required this.document,
    required this.back,
    required this.front,
    this.lightShift = 0,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = rebuildReduceMotion(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: back ? math.pi : 0),
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 520),
      curve: Curves.easeInOutCubic,
      child: front,
      builder: (context, angle, front) {
        final reverse = angle >= math.pi / 2;
        final turn = math.sin(angle);
        const perspective = .0015;
        return Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, perspective)
                ..rotateY(angle)
                ..translate(0.0, 0.0, reverse ? -1.6 : 1.6)
                ..rotateY(reverse ? math.pi : 0),
              child: CreationMaterial(
                document: document,
                glossy: !reverse,
                lightShift: reduceMotion ? 0 : lightShift + turn * .7,
                lift: 1 + turn * .2,
                child: reverse
                    ? CustomPaint(
                        painter:
                            CreationPainter(document, const [], back: true),
                      )
                    : front!,
              ),
            ),
            if (turn > .08)
              IgnorePointer(
                child: CustomPaint(
                  painter: _TurnEdge(angle, perspective),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TurnEdge extends CustomPainter {
  final double angle;
  final double perspective;
  const _TurnEdge(this.angle, this.perspective);

  @override
  void paint(Canvas canvas, Size size) {
    final sine = math.sin(angle);
    final cosine = math.cos(angle);
    Offset project(double y, double depth) {
      final x = size.width / 2;
      final z = -x * sine + depth * cosine;
      final scale = 1 / (1 + perspective * z);
      return Offset(
        x + (x * cosine + depth * sine) * scale,
        size.height / 2 + y * scale,
      );
    }

    final halfHeight = size.height / 2 - 1;
    final points = [
      project(-halfHeight, 1.6),
      project(halfHeight, 1.6),
      project(halfHeight, -1.6),
      project(-halfHeight, -1.6),
    ];
    final edge = Path()..addPolygon(points, true);
    canvas.drawPath(edge, Paint()..color = const Color(0xffd3d5d8));
  }

  @override
  bool shouldRepaint(_TurnEdge oldDelegate) =>
      oldDelegate.angle != angle || oldDelegate.perspective != perspective;
}

class CreationBackdrop extends StatelessWidget {
  final String? imageUrl;
  const CreationBackdrop({super.key, this.imageUrl});
  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: context.lgIsDark
                        ? const [
                            Color(0xff171e27),
                            Color(0xff303b49),
                            Color(0xff151a21)
                          ]
                        : const [
                            Color(0xffedf5fa),
                            Color(0xffdbe8f0),
                            Color(0xfff6f8fb)
                          ]))),
        if (imageUrl != null) ...[
          ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  alignment: Alignment.topRight,
                  memCacheWidth: 720,
                  errorWidget: (_, __, ___) => const SizedBox())),
          ColoredBox(
              color: context.lgIsDark
                  ? const Color(0xc91c232c)
                  : const Color(0x6eeef4f8)),
        ],
        DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: context.lgIsDark
                        ? const [
                            Color(0xaa171b22),
                            Color(0x00171b22),
                            Color(0xdd171b22)
                          ]
                        : const [
                            Color(0xaaf5f8fb),
                            Color(0x00f5f8fb),
                            Color(0xaaf5f8fb)
                          ],
                    stops: const [0, .48, 1]))),
      ]);
}

/// Display-only light and contact shadow. It never changes crop/ink coordinates.
class CreationMaterial extends StatelessWidget {
  final CreationDocument document;
  final Widget child;
  final double lift;
  final double lightShift;
  final bool glossy;
  const CreationMaterial(
      {super.key,
      required this.document,
      required this.child,
      this.lift = 1,
      this.lightShift = 0,
      this.glossy = false});
  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: _PaperElevation(document, lift),
      foregroundPainter: glossy ? _SurfaceLight(document, lightShift) : null,
      child: child);
}

class _SurfaceLight extends CustomPainter {
  final CreationDocument document;
  final double shift;
  const _SurfaceLight(this.document, this.shift);
  @override
  void paint(Canvas canvas, Size size) {
    if (shift.abs() < .001 ||
        document.kind == 'ticket' ||
        [
          PaperMaterial.cotton,
          PaperMaterial.linen,
          PaperMaterial.frost,
          PaperMaterial.fold
        ].contains(document.paper.material)) {
      return;
    }
    final light = shift.clamp(-1.0, 1.0);
    canvas.save();
    canvas.scale(size.width / 880, size.height / (880 / document.aspectRatio));
    for (final window in CreationPainter.photoWindows(document)) {
      canvas.drawRect(
          window,
          Paint()
            ..shader = LinearGradient(
                begin: Alignment(-1.5 + light, -1),
                end: Alignment(1 + light, 1),
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.white.withAlpha((light.abs() * 35).round()),
                  Colors.transparent
                ],
                stops: const [
                  0,
                  .3,
                  .52,
                  .75
                ]).createShader(window));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SurfaceLight oldDelegate) =>
      oldDelegate.shift != shift ||
      oldDelegate.document.templateId != document.templateId;
}

class _PaperElevation extends CustomPainter {
  final CreationDocument document;
  final double lift;
  const _PaperElevation(this.document, this.lift);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final matrix = Matrix4.identity()
      ..scale(size.width / 880, size.height / (880 / document.aspectRatio));
    final path = CreationPainter.outline(
            document, Rect.fromLTWH(0, 0, 880, 880 / document.aspectRatio))
        .transform(matrix.storage);
    // A wide lifted shadow and a tight contact shadow give different depth cues.
    canvas.drawPath(
        path.shift(Offset(1, 12 * lift)),
        Paint()
          ..color = const Color(0x230d2234)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * lift));
    canvas.drawPath(
        path.shift(const Offset(0, 1.8)),
        Paint()
          ..color = const Color(0x330d1520)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
    canvas.drawPath(
        path.shift(const Offset(.3, 1.5)),
        Paint()
          ..shader = const LinearGradient(
                  colors: [Color(0xffe3e6e9), Color(0xffc4cbd0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter)
              .createShader(rect));
  }

  @override
  bool shouldRepaint(_PaperElevation oldDelegate) =>
      oldDelegate.document.kind != document.kind ||
      oldDelegate.document.templateId != document.templateId ||
      oldDelegate.lift != lift;
}
