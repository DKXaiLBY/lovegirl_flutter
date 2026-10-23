import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../utils/lovegirl_theme.dart';
import '../utils/motion.dart';

class LovePage extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool safeArea;

  const LovePage({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 12, 18, 28),
    this.safeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    // v4.0：浅色 135° 浅灰渐变底（参考图①光感），深色维持纯色 bgDark 不上渐变
    //（v3.41 深色红线）；Scaffold 纯色 bgLight/bgDark 保留兜底。
    final body = Container(
      decoration: BoxDecoration(
        color: context.lgBg,
        gradient: context.lgIsDark
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: LoveGirlTheme.surfaceGradient,
              ),
      ),
      child: Padding(padding: padding, child: child),
    );
    return safeArea ? SafeArea(child: body) : body;
  }
}

class LovePaper extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final double radius;
  final bool elevated;
  final Border? border;

  const LovePaper({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.color,
    this.radius = LoveGirlTheme.radiusLg,
    // v4.2 默认 true：参考图的"软实体卡"——白→浅灰纵向微渐变+大范围柔影，
    // 卡片像浮起的实体；描边退居辅助（默认去线，需要线框时显式传 border）
    this.elevated = true,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final base = color ?? context.lgPaper;
    final isDark = context.lgIsDark;
    // 软实体感：顶部白→底部极浅灰的纵向微渐变（深色态用微亮渐变替代）
    final softGradient = isDark
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              base,
              Color.alphaBlend(Colors.white.withValues(alpha: 0.03), base)
            ],
          )
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              base,
              Color.alphaBlend(Colors.black.withValues(alpha: 0.018), base)
            ],
          );
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: softGradient,
        borderRadius: BorderRadius.circular(radius),
        // v4.2 描边默认去掉（参考图卡片无线框），实体感全靠渐变+柔影
        border: border,
        boxShadow: elevated ? LoveGirlTheme.cardShadow() : null,
      ),
      child: child,
    );
  }
}

class LoveStickerIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  final double iconSize;
  final Color? background;

  const LoveStickerIcon({
    super.key,
    required this.icon,
    this.color,
    this.size = 46,
    this.iconSize = 24,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? (tint ?? context.lgInk).withAlpha(20),
        borderRadius: BorderRadius.circular(size * 0.34),
        // v4.0 描边对齐 cardBorder 体系：中性默认（未传色）走细线 token；
        // 传色变体保留语义着色描边（色与图标同源，非中性发丝线）
        border: Border.all(
          color: tint != null ? tint.withAlpha(35) : context.lgCardBorder,
        ),
      ),
      child: Icon(icon, color: tint ?? context.lgInk, size: iconSize),
    );
  }
}

class LoveTicketCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;

  const LoveTicketCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TicketBorderPainter(separator: context.lgCardBorder),
      child: LovePaper(
        padding: padding,
        margin: margin,
        color: color,
        radius: LoveGirlTheme.radiusLg,
        child: child,
      ),
    );
  }
}

class LoveTicketDivider extends StatelessWidget {
  final Axis axis;
  final double length;
  final Color color;

  const LoveTicketDivider({
    super.key,
    this.axis = Axis.vertical,
    this.length = 84,
    this.color = const Color(0xFFE2E2E2),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableLength = axis == Axis.vertical
            ? constraints.maxHeight
            : constraints.maxWidth;
        final paintLength = availableLength.isFinite
            ? math.min(length, availableLength)
            : length;
        return CustomPaint(
          size: axis == Axis.vertical
              ? Size(1, paintLength)
              : Size(paintLength, 1),
          painter: _DashedLinePainter(axis: axis, color: color),
        );
      },
    );
  }
}

class LoveBarcode extends StatelessWidget {
  final Color? color;
  final double width;
  final double height;

  const LoveBarcode({
    super.key,
    this.color,
    this.width = 52,
    this.height = 38,
  });

  @override
  Widget build(BuildContext context) {
    const pattern = [2.0, 1.0, 3.0, 1.0, 1.0, 2.0, 4.0, 1.0, 2.0, 3.0];
    const gap = 2.0;
    const naturalWidth = 40.0;
    return SizedBox(
      width: width,
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth < naturalWidth
              ? constraints.maxWidth / naturalWidth
              : 1.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final bar in pattern) ...[
                Container(
                    width: bar * scale,
                    color: (color ?? context.lgTextMuted).withAlpha(150),),
                SizedBox(width: gap * scale),
              ],
            ],
          );
        },
      ),
    );
  }
}

class LovePrimaryButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? color;

  const LovePrimaryButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor: color ?? context.lgInk,
      foregroundColor: ThemeData.estimateBrightnessForColor(color ?? context.lgInk) ==
              Brightness.dark
          ? Colors.white
          : LoveGirlTheme.bgDark,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
    Widget button;
    if (icon == null) {
      button =
          FilledButton(onPressed: onPressed, style: style, child: Text(text));
    } else {
      button = FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(text),
        style: style,
      );
    }
    return PressableScale(enabled: onPressed != null, child: button);
  }
}

class LoveSectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onActionTap;

  const LoveSectionTitle({
    super.key,
    required this.title,
    this.action,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            // v4.2：标题升级为大而粗（17/w800 主字色，对齐参考图 Opportunities/Menu 级别）
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
            color: context.lgTextPrimary,
          ),
        ),
        const Spacer(),
        if (action != null)
          TextButton(
            onPressed: onActionTap,
            style: TextButton.styleFrom(
              foregroundColor: context.lgInk,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(action!),
          ),
      ],
    );
  }
}

class LovePill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? color;
  final Color? background;

  const LovePill({
    super.key,
    required this.text,
    this.icon,
    this.color,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final semanticColor = color;
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        // v4.0 默认底=lgBadgeBg（浅 badgeBg/深 primarySoftDark，深色安全）；
        // 语义色由调用方传 softXxxText 类 getter，底沿用 fg 18α 浅纱（不回退深色安全性质）
        color: background ??
            (semanticColor != null
                ? semanticColor.withAlpha(18)
                : context.lgBadgeBg),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: semanticColor != null
              ? semanticColor.withAlpha(45)
              : context.lgBadgeBg,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: semanticColor ?? context.lgInk),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: semanticColor ?? context.lgInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoveIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? color;
  final bool isActive;

  const LoveIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.color,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isActive ? context.lgPrimarySoft : context.lgPaper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                isActive ? LoveGirlTheme.primaryLight : context.lgCardBorder,
          ),
          boxShadow: LoveGirlTheme.cardShadow(),
        ),
        child: Icon(
          icon,
          color: isActive
              ? context.lgInk
              : (color ?? context.lgTextPrimary),
          size: 22,
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class LoveMenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final Color? color;

  /// v4.0 行尾计数徽章（LoveBadge 中性灰底）；与 value 互斥场景由调用方取舍，
  /// 两者同传时 value 在前、count 收尾
  final int? count;

  const LoveMenuRow({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
    this.color,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        // v4.2 行高再疏朗（14→16，参考图列表行的呼吸感）
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? context.lgInk),
            SizedBox(width: 13),
            Flexible(
              flex: 0,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.lgTextPrimary,
                ),
              ),
            ),
            if (value != null) ...[
              SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.lgTextMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (count != null) ...[
              const SizedBox(width: 8),
              // v4.2 计数改裸灰数字（参考图 Opportunities 列表：All 4 / New 5 的形态）
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.lgTextMuted,
                ),
              ),
            ],
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: context.lgTextMuted.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

/// v4.0 徽章语义色档（参考图⑥：中性浅灰为主，语义色浅底点缀）。
/// 颜色一律走 LoveGirlSemanticColors getter（深色 bg 统一 primarySoftDark），
/// 禁止直引浅色常量。
enum LoveBadgeStyle { neutral, green, orange, blue, purple, yellow }

/// v4.0 小圆角计数徽章（LoveMenuRow 行尾计数/列表角标）：
/// 默认中性=lgBadgeBg/lgBadgeText；语义传 style；红点告警传 danger: true（red 底白字）。
class LoveBadge extends StatelessWidget {
  final int? count;
  final String? text;
  final LoveBadgeStyle style;
  final bool danger;

  const LoveBadge({
    super.key,
    this.count,
    this.text,
    this.style = LoveBadgeStyle.neutral,
    this.danger = false,
  })  : assert(
          count != null || text != null,
          'LoveBadge 需要 count 或 text 之一',
        );

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (danger) {
      bg = LoveGirlTheme.red;
      fg = Colors.white;
    } else {
      switch (style) {
        case LoveBadgeStyle.neutral:
          bg = context.lgBadgeBg;
          fg = context.lgBadgeText;
        case LoveBadgeStyle.green:
          bg = context.lgSoftGreenBg;
          fg = context.lgSoftGreenText;
        case LoveBadgeStyle.orange:
          bg = context.lgSoftOrangeBg;
          fg = context.lgSoftOrangeText;
        case LoveBadgeStyle.blue:
          bg = context.lgSoftBlueBg;
          fg = context.lgSoftBlueText;
        case LoveBadgeStyle.purple:
          bg = context.lgSoftPurpleBg;
          fg = context.lgSoftPurpleText;
        case LoveBadgeStyle.yellow:
          bg = context.lgSoftYellowBg;
          fg = context.lgSoftYellowText;
      }
    }
    final label = text ?? (count! > 99 ? '99+' : '${count!}');
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.4,
          color: fg,
        ),
      ),
    );
  }
}

/// v4.0 竖向连接线子列表（参考图⑤ Threads/Income 展开态）：
/// 左侧 1px 竖线（lgSeparator）+ 16px 缩进，行内容用 [LoveThreadRow]。
class LoveThreadList extends StatelessWidget {
  final List<Widget> children;
  final Color? lineColor;
  final double indent;

  const LoveThreadList({
    super.key,
    required this.children,
    this.lineColor,
    this.indent = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final line = lineColor ?? context.lgSeparator;
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++)
            _LoveThreadRail(
              lineColor: line,
              isLast: i == children.length - 1,
              child: children[i],
            ),
        ],
      ),
    );
  }
}

/// 单条竖线导轨：非末行贯通整行高，末行止于半高（停在内容中线）。
/// IntrinsicHeight 取内容真实高度，保证滚动视图内竖线不塌陷。
class _LoveThreadRail extends StatelessWidget {
  final Color lineColor;
  final bool isLast;
  final Widget child;

  const _LoveThreadRail({
    required this.lineColor,
    required this.isLast,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 1,
            child: Align(
              alignment: Alignment.topCenter,
              child: FractionallySizedBox(
                widthFactor: 1,
                heightFactor: isLast ? 0.5 : 1,
                child: ColoredBox(color: lineColor),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// 竖线子行：普通态=素行文本；selected=白胶囊+细线描边（参考图⑤选中态）。
class LoveThreadRow extends StatelessWidget {
  final Widget child;
  final bool selected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const LoveThreadRow({
    super.key,
    required this.child,
    this.selected = false,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    final Widget content;
    if (selected) {
      // v4.2 选中态=浅灰胶囊+柔影（参考图 All/Embed Tool 行；黑胶囊只留给主按钮）
      content = Container(
        padding: padding,
        decoration: BoxDecoration(
          color: context.lgPrimarySoft,
          borderRadius: radius,
          boxShadow: LoveGirlTheme.cardShadow(),
        ),
        child: child,
      );
    } else {
      content = Padding(padding: padding, child: child);
    }
    return Padding(
      // 行间呼吸感计入行高（竖线经 _LoveThreadRail 贯通，视觉连续）
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: onTap == null
          ? content
          : InkWell(borderRadius: radius, onTap: onTap, child: content),
    );
  }
}

class _TicketBorderPainter extends CustomPainter {
  final Color separator;

  _TicketBorderPainter({required this.separator});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withAlpha(210),
          separator.withAlpha(150),
          separator.withAlpha(120),
        ],
      ).createShader(Offset.zero & size);

    const notchRadius = 8.0;
    const radius = LoveGirlTheme.radiusLg;
    final path = Path()
      ..moveTo(radius, 0)
      ..lineTo(size.width - radius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, radius)
      ..lineTo(size.width, size.height / 2 - notchRadius)
      ..arcToPoint(
        Offset(size.width, size.height / 2 + notchRadius),
        radius: const Radius.circular(notchRadius),
        clockwise: false,
      )
      ..lineTo(size.width, size.height - radius)
      ..quadraticBezierTo(
          size.width, size.height, size.width - radius, size.height)
      ..lineTo(radius, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - radius)
      ..lineTo(0, size.height / 2 + notchRadius)
      ..arcToPoint(
        Offset(0, size.height / 2 - notchRadius),
        radius: const Radius.circular(notchRadius),
        clockwise: false,
      )
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedLinePainter extends CustomPainter {
  final Axis axis;
  final Color color;

  const _DashedLinePainter({required this.axis, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha(170)
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 4.0;
    double current = 0;
    final max = axis == Axis.vertical ? size.height : size.width;
    while (current < max) {
      final next = (current + dash).clamp(0.0, max).toDouble();
      if (axis == Axis.vertical) {
        canvas.drawLine(Offset(0, current), Offset(0, next), paint);
      } else {
        canvas.drawLine(Offset(current, 0), Offset(next, 0), paint);
      }
      current += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) {
    return oldDelegate.axis != axis || oldDelegate.color != color;
  }
}
