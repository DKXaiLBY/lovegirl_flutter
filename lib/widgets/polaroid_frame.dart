import 'package:flutter/material.dart';

import 'polaroid_theme.dart';

/// 实体拍立得相纸复刻（v3.38 Step2 返工，参照实物+refs 第二批参考图）：
/// - 比例锁定 88:107 ≈ 1:1.216，照片窗正方形，底边宽度=侧边 3 倍+
/// - 相纸非纯白：奶白底 + paper_grain 噪点贴片（实体纸感）
/// - 照片窗"凹进去"：内压边（深色内描边+1px 高光）
/// - 照片显影色：ColorFilter 柔化对比/提灰黑位/偏暖 + 斜向光泽
/// - 实体阴影：近实远虚两层
/// - 底边：马克笔手写日期（微歪）+ 白框手写字（非输入框）
class PolaroidFrame extends StatelessWidget {
  final Widget photo;
  final DateTime? date;
  final String caption;
  final PolaroidTheme theme;
  final List<InkStroke> inkStrokes;
  final bool inkEnabled;
  final ValueChanged<List<InkStroke>>? onInkChanged;
  final double rotation;
  final VoidCallback? onCaptionTap;
  final Widget? overlay;

  const PolaroidFrame({
    super.key,
    required this.photo,
    this.date,
    this.caption = '',
    this.theme = PolaroidTheme.classic,
    this.inkStrokes = const [],
    this.inkEnabled = false,
    this.onInkChanged,
    this.rotation = 0,
    this.onCaptionTap,
    this.overlay,
  });

  /// 拍立得显影色：黑位提灰、对比柔化、中间调偏暖（胶片乳剂感）
  static const ColorFilter _grade = ColorFilter.matrix(<double>[
    0.94, 0.05, 0.01, 0, 0.035, //
    0.03, 0.95, 0.02, 0, 0.022, //
    0.02, 0.05, 0.87, 0, 0.055, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final t = theme.style;
    // 顶部 LayoutBuilder 自算全部显式尺寸（弃用嵌套 AspectRatio——
    // 紧约束父级下 AspectRatio 会失效导致 Column 溢出 318px，二分诊断实锤）
    return Transform.rotate(
      angle: rotation,
      child: LayoutBuilder(builder: (context, box) {
        var w = box.maxWidth;
        // 防御：可用高度有限时收缩宽度，保证相纸比例内容永不溢出
        // （紧约束父级如 ListView/根节点会把宽度撑到与高度失配）
        final maxH = box.maxHeight;
        if (maxH.isFinite) {
          final decorH = t.topDecorHeight;
          final maxWForH =
              (maxH - w * 0.057 - decorH - w * 0.15) * 88 / 107;
          if (maxWForH > 60 && maxWForH < w) w = maxWForH;
        }
        final h = w * 107 / 88; // 相纸比例 88:107
        final pad = w * 0.057; // 侧边/顶边（≈5.7%）
        final decorH = t.topDecorHeight; // 顶部装饰条占高
        final photoH = w - 2 * pad; // 照片窗正方形
        final bandH = h - pad - decorH - photoH; // 底边 = 剩余全部（≈25.6%）
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: w,
            height: h,
            child: Container(
              decoration: BoxDecoration(
                color: t.frameColor,
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  // 近处硬影（厚卡纸）
                  BoxShadow(
                    color: Colors.black.withAlpha(64),
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                  // 远处环境影
                  BoxShadow(
                    color: Colors.black.withAlpha(38),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Stack(
                  children: [
                    // 相纸内容（全部显式高度，Column 不可能溢出）
                    Padding(
                      padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (t.topDecor != null)
                            Padding(
                              padding: EdgeInsets.only(bottom: pad * 0.5),
                              child: t.topDecor!,
                            ),
                          // 照片窗（显式正方形，凹进）
                          SizedBox(
                            height: photoH,
                            child: Stack(
                              children: [
                                // 显影色
                                ColorFiltered(
                                  colorFilter: _grade,
                                  child: photo,
                                ),
                                // 斜向光泽（乳剂面反光）
                                const Positioned.fill(
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment(0.4, 0.6),
                                          colors: [
                                            Color(0x2EFFFFFF),
                                            Color(0x00FFFFFF),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // 涂鸦层
                                Positioned.fill(
                                  child: InkCanvas(
                                    strokes: inkStrokes,
                                    enabled: inkEnabled,
                                    defaultColor:
                                        theme == PolaroidTheme.film ||
                                                theme == PolaroidTheme.tape
                                            ? const Color(0xFFECECEE)
                                            : const Color(0xFF33332F),
                                    onChanged: (s) => onInkChanged?.call(s),
                                  ),
                                ),
                                // 内压边（照片窗凹进的边缘）
                                const Positioned.fill(
                                  child: IgnorePointer(
                                    child: _WindowBevel(),
                                  ),
                                ),
                                if (overlay != null) overlay!,
                              ],
                            ),
                          ),
                          // 底边（宽）：手写日期 + 白框手写字
                          SizedBox(
                            height: bandH,
                            child: _BottomBand(
                              theme: theme,
                              date: date,
                              caption: caption,
                              onCaptionTap: onCaptionTap,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 纸纹颗粒（整张相纸）
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: 0.55,
                          child: Image(
                            image:
                                AssetImage('assets/images/deco/paper_grain.png'),
                            repeat: ImageRepeat.repeat,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// 照片窗内压边：4px 深色内沿 + 1px 高光沿，制造"嵌进去"的错觉
class _WindowBevel extends StatelessWidget {
  const _WindowBevel();

  @override
  Widget build(BuildContext context) {
    return Container(
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.black.withAlpha(34), width: 4),
      ),
      child: Container(
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
              color: const Color(0x30FFFFFF), width: 1),
        ),
      ),
    );
  }
}

/// 底边内容：日期（微歪马克笔感）+ 手写字（点击弹出编辑）；
/// letter 主题：日期装进红描边 DATE 小牌
class _BottomBand extends StatelessWidget {
  final PolaroidTheme theme;
  final DateTime? date;
  final String caption;
  final VoidCallback? onCaptionTap;

  const _BottomBand({
    required this.theme,
    required this.date,
    required this.caption,
    this.onCaptionTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme.style;
    final d = date;
    final hasCaption = caption.trim().isNotEmpty;

    Widget dateWidget = Transform.rotate(
      angle: -0.035,
      child: HandwrittenDate(
        date: d ?? DateTime.now(),
        color: t.captionColor,
        fontSize: 19,
      ),
    );

    if (theme == PolaroidTheme.letter) {
      dateWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: t.captionColor, width: 1.2),
        ),
        child: dateWidget,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          dateWidget,
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCaptionTap,
              child: Transform.rotate(
                angle: 0.012,
                child: Text(
                  hasCaption ? caption : (onCaptionTap != null ? '✎' : ''),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Caveat',
                    fontSize: 16,
                    height: 1.05,
                    fontWeight: FontWeight.w600,
                    color: t.captionColor.withAlpha(hasCaption ? 255 : 120),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
