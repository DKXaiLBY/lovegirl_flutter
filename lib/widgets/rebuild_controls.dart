import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/map_prefs_provider.dart';
import '../utils/lovegirl_theme.dart';

bool rebuildReduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    context.watch<MapPrefsProvider?>()?.motionLevel == 'off';

ButtonStyle rebuildFilledStyle(BuildContext context) => FilledButton.styleFrom(
    backgroundColor: context.lgInk,
    foregroundColor: context.lgPaper,
    iconColor: context.lgPaper,
    disabledBackgroundColor: context.lgSeparator,
    disabledForegroundColor: context.lgTextSecondary,
    minimumSize: const Size(48, 48),
    shape: const StadiumBorder(),
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12));

ButtonStyle rebuildTextStyle(BuildContext context) => TextButton.styleFrom(
    foregroundColor: context.lgInk, iconColor: context.lgInk);

ButtonStyle rebuildOutlinedStyle(BuildContext context) =>
    OutlinedButton.styleFrom(
        foregroundColor: context.lgInk, iconColor: context.lgInk);

class RebuildChoiceChip extends StatelessWidget {
  final Widget label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  const RebuildChoiceChip(
      {super.key,
      required this.label,
      required this.selected,
      this.onSelected});
  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: label,
        selected: selected,
        onSelected: onSelected == null
            ? null
            : (value) {
                HapticFeedback.selectionClick();
                onSelected!(value);
              },
        materialTapTargetSize: MaterialTapTargetSize.padded,
        showCheckmark: false,
        selectedColor: context.lgInk,
        backgroundColor:
            context.lgPaper.withAlpha(context.lgIsDark ? 115 : 125),
        surfaceTintColor: Colors.transparent,
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
            color: selected ? context.lgPaper : context.lgInk,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
        side: BorderSide(
            color: selected ? context.lgInk : context.lgPaper.withAlpha(195)),
      );
}

class RebuildGlass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  const RebuildGlass(
      {super.key,
      required this.child,
      this.radius = 28,
      this.padding = EdgeInsets.zero});
  @override
  Widget build(BuildContext context) {
    final dark = context.lgIsDark;
    final border = BorderRadius.circular(radius);
    return DecoratedBox(
        decoration: BoxDecoration(borderRadius: border, boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(dark ? 40 : 18),
              blurStyle: BlurStyle.outer,
              blurRadius: 20,
              offset: const Offset(0, 6)),
        ]),
        child: ClipRRect(
            borderRadius: border,
            child: BackdropFilter(
                filter: ImageFilter.compose(
                    outer: ImageFilter.blur(sigmaX: 1.8, sigmaY: 1.8),
                    inner: ImageFilter.matrix(
                        (Matrix4.identity()..scale(1.025, 1.025)).storage,
                        filterQuality: FilterQuality.medium)),
                child: CustomPaint(
                    foregroundPainter: _GlassRim(radius, dark),
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: dark
                                    ? const [
                                        Color(0x703a424a),
                                        Color(0x9920262d),
                                        Color(0x66323c46)
                                      ]
                                    : const [
                                        Color(0x77ffffff),
                                        Color(0x42ffffff),
                                        Color(0x66e9f3fb)
                                      ],
                                stops: const [0, .55, 1])),
                        child: Material(
                            type: MaterialType.transparency,
                            child: Padding(padding: padding, child: child)))))));
  }
}

// The clear center preserves the background; the rim carries the lens highlight.
class _GlassRim extends CustomPainter {
  final double radius;
  final bool dark;
  const _GlassRim(this.radius, this.dark);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rim =
        RRect.fromRectAndRadius(rect.deflate(.7), Radius.circular(radius));
    canvas.drawRRect(
        rim,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [
                      Color(0xaaeff9ff),
                      Color(0x183f6078),
                      Color(0x77d3eaff)
                    ]
                  : const [Colors.white, Color(0x4094aec2), Color(0xeeffffff)],
              stops: const [0, .54, 1]).createShader(rect));
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(2.5), Radius.circular(radius)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00ffffff), Color(0x3399aebb), Color(0x99ffffff)],
              stops: [0, .8, 1]).createShader(rect));
  }

  @override
  bool shouldRepaint(_GlassRim oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.dark != dark;
}

class RebuildGlassButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;
  final bool showLabel;
  const RebuildGlassButton(
      {super.key,
      required this.label,
      required this.icon,
      required this.onPressed,
      this.selected = false,
      this.showLabel = false});
  @override
  State<RebuildGlassButton> createState() => _RebuildGlassButtonState();
}

class _RebuildGlassButtonState extends State<RebuildGlassButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final ink = widget.selected
        ? context.lgPaper
        : enabled
            ? context.lgInk
            : context.lgTextSecondary;
    return Tooltip(
        message: widget.label,
        excludeFromSemantics: true,
        child: AnimatedScale(
            scale: _pressed && enabled ? .95 : 1,
            duration: rebuildReduceMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 130),
            curve: Curves.easeOutCubic,
            child: RebuildGlass(
                radius: 30,
                child: Material(
                    color: widget.selected ? context.lgInk : Colors.transparent,
                    borderRadius: BorderRadius.circular(30),
                    child: InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onHighlightChanged: (value) =>
                            setState(() => _pressed = value),
                        onTap: !enabled
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                widget.onPressed!();
                              },
                        child: Semantics(
                            button: true,
                            enabled: enabled,
                            selected: widget.selected,
                            label: widget.label,
                            excludeSemantics: true,
                            child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                    minWidth: 48, minHeight: 48),
                                child: Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: widget.showLabel ? 16 : 12,
                                        vertical: 12),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(widget.icon,
                                              color: ink, size: 22),
                                          if (widget.showLabel) ...[
                                            const SizedBox(width: 8),
                                            Text(widget.label,
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: ink))
                                          ]
                                        ])))))))));
  }
}
