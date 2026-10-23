import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/map_prefs_provider.dart';
import '../utils/lovegirl_theme.dart';

/// 仅用于操作层；高对比度/辅助导航模式使用稳定底色。
class MemoryGlass extends StatelessWidget {
  final Widget child;
  const MemoryGlass({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final stable = MediaQuery.highContrastOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        enabled: !stable,
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.lgPaper.withAlpha(stable ? 255 : 235),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.lgCardBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 操作期间保持尺寸和文字状态，屏蔽连点；反馈绘制在材质上方。
class MemoryAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final String busyLabel;
  final Future<void> Function()? onPressed;

  const MemoryAction({
    super.key,
    required this.icon,
    required this.label,
    this.busyLabel = '处理中',
    required this.onPressed,
  });

  @override
  State<MemoryAction> createState() => _MemoryActionState();
}

class _MemoryActionState extends State<MemoryAction> {
  bool _busy = false;
  bool _pressed = false;

  Future<void> _run() async {
    if (_busy || widget.onPressed == null) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_busy && widget.onPressed != null;
    final motionOff = context.watch<MapPrefsProvider?>()?.motionLevel == 'off';
    return AnimatedScale(
      scale: _pressed &&
              enabled &&
              !motionOff &&
              !MediaQuery.disableAnimationsOf(context)
          ? 0.985
          : 1,
      duration: const Duration(milliseconds: 100),
      child: MemoryGlass(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? _run : null,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_busy)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: context.lgInk),
                      )
                    else
                      Icon(widget.icon,
                          size: 20,
                          color: enabled ? context.lgInk : context.lgTextMuted),
                    const SizedBox(width: 8),
                    Flexible(
                        child: Text(_busy ? widget.busyLabel : widget.label,
                            style: TextStyle(
                                color: enabled || _busy
                                    ? context.lgTextPrimary
                                    : context.lgTextMuted))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
