import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 数字形象伪 3D 视差（W4）：背景原图与人像透明层反向错动。
/// 交互=手势横拖（主）+ 极轻待机摆（让效果可被发现）；无新权限、无新依赖。
/// 前提：cutoutUrl 与 imageUrl 同尺寸（bda SegmentPortraitPic 返回同尺寸透明 PNG，
/// v3.36 实证）→ 双图同 BoxFit.cover 像素对齐；cutout 加载失败自动退化单层。
/// 对抗审查修正已并入：onHorizontalDrag（不吃垂直滚动）/人像层占位透明/
/// 背景外扩 1.10 覆盖极端位移/双层同 memCacheWidth 对齐缓存。
class ParallaxAvatar extends StatefulWidget {
  final String imageUrl; // 背景原图（完整 URL）
  final String cutoutUrl; // 人像透明图（完整 URL）
  final BorderRadius? borderRadius;

  const ParallaxAvatar({
    super.key,
    required this.imageUrl,
    required this.cutoutUrl,
    this.borderRadius,
  });

  @override
  State<ParallaxAvatar> createState() => _ParallaxAvatarState();
}

class _ParallaxAvatarState extends State<ParallaxAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3600))
    ..repeat();
  late final AnimationController _return =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  Animatable<double>? _returnTween; // 松手弹回（begin=松手瞬间值，防跳变）
  double _drag = 0;
  double _dragStart = 0;

  @override
  void dispose() {
    _idle.dispose();
    _return.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails d) {
    _return.stop();
    _returnTween = null;
    _dragStart = _drag;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final width = (context.size?.width ?? 320) * 0.45;
    setState(() {
      _drag = (_dragStart + d.primaryDelta! / width).clamp(-1.0, 1.0);
    });
  }

  void _onDragEnd(DragEndDetails d) {
    _returnTween =
        Tween<double>(begin: _drag, end: 0).chain(CurveTween(curve: Curves.easeOutCubic));
    _return.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: AnimatedBuilder(
          animation: Listenable.merge([_idle, _return]),
          builder: (context, _) {
            final drag = _return.isAnimating
                ? (_returnTween?.evaluate(_return) ?? _drag)
                : _drag;
            final tilt =
                (math.sin(_idle.value * 2 * math.pi) * 0.25 + drag)
                    .clamp(-1.2, 1.2);
            return Stack(
              fit: StackFit.expand,
              children: [
                // 背景层：原图外扩 10% 覆盖极端位移，反向轻移
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.translationValues(-tilt * 7, 0, 0)
                    ..scale(1.10, 1.10),
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    placeholder: (_, __) => const SizedBox.shrink(),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                // 背景轻压暗（人像聚焦，深浅两态通用）
                ColoredBox(color: Colors.black.withAlpha(20)),
                // 人像层：透明 PNG 正向移动 + 微旋转微缩放（加载中透明，不挡背景）
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.translationValues(tilt * 14, 0, 0)
                    ..rotateZ(tilt * 0.015)
                    ..scale(1 + tilt.abs() * 0.03, 1 + tilt.abs() * 0.03, 1),
                  child: CachedNetworkImage(
                    imageUrl: widget.cutoutUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    placeholder: (_, __) => const SizedBox.shrink(),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
