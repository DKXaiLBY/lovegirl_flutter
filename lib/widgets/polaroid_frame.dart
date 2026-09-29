import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'polaroid_theme.dart';

/// 相纸实际渲染尺寸：由父级约束自算（可用高度不足时收缩宽度，保证比例内容永不
/// 溢出——紧约束父级如 GridView cell/根节点会把宽度撑到与高度失配）。
/// PolaroidFrame 内部与 photo_screen._PolaroidTile 的阴影/侧边层必须用同一公式，
/// 否则阴影与卡片错位（cell 紧约束下卡片只占约 83% 宽，不能拿 cell 尺寸当卡片尺寸）。
Size polaroidCardSize(BoxConstraints box, {required double topDecorHeight}) {
  var w = box.maxWidth;
  final maxH = box.maxHeight;
  if (maxH.isFinite) {
    final maxWForH = (maxH - w * 0.057 - topDecorHeight - w * 0.15) * 88 / 107;
    if (maxWForH > 60 && maxWForH < w) w = maxWForH;
  }
  return Size(w, w * 107 / 88); // 相纸比例 88:107
}

/// 静置双层影：近硬影（厚卡纸）+ 远环境影。PolaroidFrame 默认阴影与
/// _PolaroidTile 翻面端点态（θ=0/π）必须是同一组值，翻完静置才无跳变。
const List<BoxShadow> kPolaroidRestShadows = [
  BoxShadow(color: Color(0x40000000), blurRadius: 3, offset: Offset(0, 2)),
  BoxShadow(color: Color(0x26000000), blurRadius: 22, offset: Offset(0, 12)),
];

/// 翻面角 θ∈[0,π] 对应的落影：静置时与 kPolaroidRestShadows 相同；
/// 翻起中段卡片"抬起"——影子向下偏移、变大变虚变淡（blur/透明度增幅比位移大，
/// 否则中段读起来像第二张灰卡而不是影子）。纯函数便于单测，
/// sin 在 π/2 两侧对称保证换面瞬间影子连续。
List<BoxShadow> polaroidCastShadows(double flipAngle) {
  final lift = math.sin(flipAngle).clamp(0.0, 1.0);
  if (lift <= 0.002) return kPolaroidRestShadows;
  return [
    BoxShadow(
      color: Colors.black.withAlpha((64 - 30 * lift).round()),
      blurRadius: 3 + 30 * lift,
      offset: Offset(14 * lift, 2 + 16 * lift),
    ),
    kPolaroidRestShadows[1],
  ];
}

/// 翻面进度 → 光泽平移量（0..1，0=静置位）。照片窗高光随翻面扫动（动态光泽）。
double polaroidGlossShift(double flipAngle) => math.sin(flipAngle);

/// 厚度侧边宽：卡纸厚约 1.8% 卡宽，正视角投影 = 厚 × |sinθ|，静置为 0
double polaroidEdgeWidth(double cardWidth, double flipAngle) =>
    cardWidth * 0.018 * math.sin(flipAngle).abs();

/// 厚度侧边出现在哪一侧：golden 实测 rotationY 正角 = 右缘朝向观察者
/// （前半程近缘在右、换面后背面近缘在左；与右手系直觉相反，以渲染为准）
bool polaroidEdgeOnLeft(double flipAngle) => flipAngle >= math.pi / 2;

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

  /// 动态光泽平移量（-1..1，0=静置位）。翻面时由 _PolaroidTile 传 sin(θ)，
  /// 编辑弹层不传（保持静置光泽——保存的 PNG 必须是"静置的实物照"）。
  /// 只作用于前半程翻面（后半程正面不在树里，背面无光泽，符合实物）。
  final double glossShift;

  /// 是否由本组件自绘静置双层影。_PolaroidTile 翻面场景传 false，
  /// 落影改由 tile 在翻面旋转之外绘制（影子不随卡旋转、翻起时变形）。
  final bool shadows;

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
    this.glossShift = 0,
    this.shadows = true,
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
        final decorH = t.topDecorHeight;
        final card = polaroidCardSize(box, topDecorHeight: decorH);
        final w = card.width;
        final h = card.height;
        final pad = w * 0.057; // 侧边/顶边（≈5.7%）
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
                boxShadow: shadows ? kPolaroidRestShadows : null,
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
                                // 斜向光泽（乳剂面反光）——glossShift>0 时高光随翻面扫动
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment(
                                              -1.0 + glossShift, -1.0),
                                          end: Alignment(
                                              0.4 + glossShift, 0.6),
                                          colors: const [
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
                    // 相纸微弯（实体纸边缘张力）：上下边缘极轻压暗 + 1px 受光亮线。
                    // 压暗只对浅色主题可见（tape/film 深底不可见，无害）；
                    // 亮线在深浅主题都给边缘一点受光。画在纸纹层之下，被噪点融合。
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [0, 0.03, 0.97, 1],
                              colors: [
                                Color(0x0A000000),
                                Color(0x00000000),
                                Color(0x00000000),
                                Color(0x0C000000),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 1,
                      left: 1,
                      right: 1,
                      height: 1,
                      child: IgnorePointer(
                        child:
                            ColoredBox(color: Colors.white.withAlpha(20)),
                      ),
                    ),
                    Positioned(
                      bottom: 1,
                      left: 1,
                      right: 1,
                      height: 1,
                      child: IgnorePointer(
                        child:
                            ColoredBox(color: Colors.white.withAlpha(20)),
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
