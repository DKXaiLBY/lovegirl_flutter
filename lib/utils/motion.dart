import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:lovegirl_flutter/providers/map_prefs_provider.dart';

/// 动效强度：'off' | 'standard' | 'rich'
/// 由 MapPrefsProvider.motionLevel 持久化，设置页可切换。

/// 列表卡片错峰浮现：按 index 依次上移+淡入
class StaggerIn extends StatefulWidget {
  final int index;
  final Widget child;
  final double dy;

  const StaggerIn({
    super.key,
    required this.index,
    required this.child,
    this.dy = 16,
  });

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 430));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final level = context.read<MapPrefsProvider>().motionLevel;
    if (level == 'off') {
      _ctrl.value = 1;
    } else {
      final step = level == 'rich' ? 85 : 50;
      final delay = min(widget.index * step, 480);
      _timer = Timer(Duration(milliseconds: delay), () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_ctrl.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, widget.dy * (1 - t)),
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// 数字滚动：从 0 滚到目标值（动效关闭时静态显示）
class RollingNumber extends StatelessWidget {
  final int value;
  final TextStyle style;

  const RollingNumber({super.key, required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    final level = context.watch<MapPrefsProvider>().motionLevel;
    if (level == 'off') {
      return Text(value.toString(), style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 950),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) =>
          Text(v.round().toString(), style: style),
    );
  }
}

/// 时光感知氛围层：清晨/白天/傍晚/深夜给内容盖一层低透明度色调，
/// 深夜明显变暗。返回 null 表示无需叠加。
Widget? timeAmbienceOverlay() {
  final hour = DateTime.now().hour;
  Gradient? gradient;
  if (hour >= 23 || hour < 6) {
    // 深夜：明显压暗
    gradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x52140F0C), Color(0x6B140F0C)],
    );
  } else if (hour >= 17 && hour < 20) {
    // 傍晚：暖橙
    gradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x2BE7A25D), Color(0x0DE7A25D)],
    );
  } else if (hour >= 5 && hour < 8) {
    // 清晨：微金
    gradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x1FFFF3D6), Color(0x00FFF3D6)],
    );
  }
  if (gradient == null) return null;
  return IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: const SizedBox.expand(),
    ),
  );
}

/// 按压缩放反馈（动效关闭时不缩放）
class PressableScale extends StatefulWidget {
  final Widget child;
  const PressableScale({super.key, required this.child});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final level = context.watch<MapPrefsProvider>().motionLevel;
    final enabled = level != 'off';
    return Listener(
      onPointerDown: (_) {
        if (enabled) setState(() => _down = true);
      },
      onPointerUp: (_) {
        if (_down) setState(() => _down = false);
      },
      onPointerCancel: (_) {
        if (_down) setState(() => _down = false);
      },
      child: AnimatedScale(
        scale: _down ? 0.965 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
