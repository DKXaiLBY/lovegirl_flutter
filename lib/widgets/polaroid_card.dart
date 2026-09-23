import 'package:flutter/material.dart';

import '../utils/lovegirl_theme.dart';

/// 拍立得相纸卡：白框、轻微旋转、顶部和纸胶带（PNG 素材，非代码绘制）。
/// 深色模式下胶带降低透明度；相纸保持纸白（实体隐喻，同纸质票根卡）。
class PolaroidCard extends StatelessWidget {
  /// 照片区（建议定高，内部自行 clip）。
  final Widget photo;

  /// 相纸下方白边区（标题/日期/留言）。
  final Widget? caption;

  /// 旋转弧度，建议 ±0.02（约 ±1.2°）。
  final double rotation;

  /// 胶带素材路径，如 assets/images/deco/tape_sage.png；null 不贴。
  final String? tapeAsset;

  final EdgeInsetsGeometry padding;

  const PolaroidCard({
    super.key,
    required this.photo,
    this.caption,
    this.rotation = 0,
    this.tapeAsset,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.lgIsDark;
    return Transform.rotate(
      angle: rotation,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(dark ? 60 : 30),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: photo,
                ),
                if (caption != null) ...[
                  const SizedBox(height: 9),
                  caption!,
                ],
              ],
            ),
            if (tapeAsset != null)
              Positioned(
                top: -13,
                left: 0,
                right: 0,
                child: Center(
                  child: Transform.rotate(
                    angle: -0.06,
                    child: Opacity(
                      opacity: dark ? 0.5 : 1,
                      child: Image.asset(
                        tapeAsset!,
                        width: 112,
                        height: 26,
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
