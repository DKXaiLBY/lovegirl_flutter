import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/lovegirl_theme.dart';
import 'creation_canvas.dart';
import 'creation_document.dart';

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
              IconButton(
                  tooltip: _back ? '翻到正面' : '翻到背面',
                  icon: const Icon(Icons.flip),
                  onPressed: () {
                    _transform.value = Matrix4.identity();
                    setState(() => _back = !_back);
                  })
            ]),
        body: SafeArea(
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
                        child: _back
                            ? CustomPaint(
                                painter: CreationPainter(
                                    widget.document, const [],
                                    back: true))
                            : widget.front)));
          })),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Text('双指缩放，拖动查看细节',
                  style:
                      TextStyle(fontSize: 12, color: context.lgTextSecondary))),
        ])),
      );
}
