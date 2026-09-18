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
    final body = Container(
      decoration: const BoxDecoration(
        color: LoveGirlTheme.bgLight,
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
  final Color color;
  final double radius;
  final bool elevated;
  final Border? border;

  const LovePaper({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.color = LoveGirlTheme.paper,
    this.radius = LoveGirlTheme.radiusLg,
    this.elevated = true,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border ?? Border.all(color: LoveGirlTheme.separator),
        boxShadow: elevated ? LoveGirlTheme.cardShadow() : null,
      ),
      child: child,
    );
  }
}

class LoveStickerIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final Color? background;

  const LoveStickerIcon({
    super.key,
    required this.icon,
    this.color = LoveGirlTheme.primary,
    this.size = 46,
    this.iconSize = 24,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? color.withAlpha(20),
        borderRadius: BorderRadius.circular(size * 0.34),
        border: Border.all(color: color.withAlpha(35)),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

class LoveTicketCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color color;

  const LoveTicketCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.color = LoveGirlTheme.paper,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TicketBorderPainter(),
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
    this.color = const Color(0xFFE0D8D0),
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
  final Color color;
  final double width;
  final double height;

  const LoveBarcode({
    super.key,
    this.color = LoveGirlTheme.textMuted,
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
                Container(width: bar * scale, color: color.withAlpha(150)),
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
  final Color color;

  const LovePrimaryButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.color = LoveGirlTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
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
    return PressableScale(child: button);
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
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: LoveGirlTheme.textPrimary,
          ),
        ),
        const Spacer(),
        if (action != null)
          TextButton(
            onPressed: onActionTap,
            style: TextButton.styleFrom(
              foregroundColor: LoveGirlTheme.primary,
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
  final Color color;
  final Color? background;

  const LovePill({
    super.key,
    required this.text,
    this.icon,
    this.color = LoveGirlTheme.primary,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? color.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
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
                color: color,
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
  final Color color;
  final bool isActive;

  const LoveIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.color = LoveGirlTheme.textPrimary,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isActive ? LoveGirlTheme.primarySoft : LoveGirlTheme.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isActive ? LoveGirlTheme.primaryLight : LoveGirlTheme.separator,
          ),
          boxShadow: LoveGirlTheme.cardShadow(),
        ),
        child: Icon(
          icon,
          color: isActive ? LoveGirlTheme.primary : color,
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
  final Color color;

  const LoveMenuRow({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
    this.color = LoveGirlTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 13),
            Flexible(
              flex: 0,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: LoveGirlTheme.textPrimary,
                ),
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    color: LoveGirlTheme.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: LoveGirlTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketBorderPainter extends CustomPainter {
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
          LoveGirlTheme.separator.withAlpha(150),
          LoveGirlTheme.separator.withAlpha(120),
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
