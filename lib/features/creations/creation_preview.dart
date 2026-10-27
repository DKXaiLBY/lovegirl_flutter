import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/rebuild_controls.dart';
import 'creation_canvas.dart';
import 'creation_document.dart';
import 'creation_material.dart';

class CreationPreview extends StatefulWidget {
  final CreationDocument document;
  final Widget front;
  final bool initialBack;
  const CreationPreview(
      {super.key,
      required this.document,
      required this.front,
      this.initialBack = false});
  @override
  State<CreationPreview> createState() => _CreationPreviewState();
}

class _CreationPreviewState extends State<CreationPreview> {
  final _transform = TransformationController();
  late bool _back = widget.initialBack;
  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.lgBg,
        appBar: AppBar(
            systemOverlayStyle: context.lgIsDark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            title: Text(widget.document.kind == 'ticket' ? '票根预览' : '拍立得预览'),
            actions: [
              Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: RebuildGlassButton(
                      label: _back ? '翻到正面' : '翻到背面',
                      icon: Icons.flip,
                      onPressed: () {
                        _transform.value = Matrix4.identity();
                        setState(() => _back = !_back);
                      }))
            ]),
        body: Stack(children: [
          const Positioned.fill(child: CreationBackdrop()),
          SafeArea(
              child: Column(children: [
            Expanded(child: LayoutBuilder(builder: (context, constraints) {
              final width = math.min(constraints.maxWidth - 32,
                  (constraints.maxHeight - 32) * widget.document.aspectRatio);
              return InteractiveViewer(
                  transformationController: _transform,
                  minScale: 1,
                  maxScale: 5,
                  boundaryMargin: const EdgeInsets.all(60),
                  child: Center(
                      child: SizedBox(
                          width: width,
                          height: width / widget.document.aspectRatio,
                          child: TweenAnimationBuilder<double>(
                              tween: Tween(end: _back ? math.pi : 0),
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 420),
                              curve: Curves.easeInOutCubic,
                              builder: (context, angle, _) => Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, .0015)
                                    ..rotateY(angle > math.pi / 2
                                        ? angle - math.pi
                                        : angle),
                                  child: CreationMaterial(
                                      document: widget.document,
                                      glossy: angle < math.pi / 2,
                                      lightShift:
                                          MediaQuery.disableAnimationsOf(
                                                  context)
                                              ? 0
                                              : math.sin(angle) * .7,
                                      child: angle > math.pi / 2
                                          ? CustomPaint(
                                              painter: CreationPainter(
                                                  widget.document, const [],
                                                  back: true))
                                          : widget.front))))));
            })),
            Padding(
                padding: const EdgeInsets.all(16),
                child: Text('双指缩放，拖动查看细节',
                    style: TextStyle(
                        fontSize: 12, color: context.lgTextSecondary))),
          ]))
        ]),
      );
}
