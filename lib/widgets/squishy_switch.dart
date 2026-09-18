import 'package:flutter/material.dart';

import '../utils/lovegirl_theme.dart';

/// 弹性开关（SQUASH）：起步滑块横向拉长，落位后压回，带质量感
class SquishySwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const SquishySwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<SquishySwitch> createState() => _SquishySwitchState();
}

class _SquishySwitchState extends State<SquishySwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: widget.value ? 1.0 : 0.0);
  late bool _on = widget.value;

  @override
  void didUpdateWidget(covariant SquishySwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _on = widget.value;
      _ctrl.animateTo(_on ? 1 : 0,
          curve: const Cubic(.34, 1.56, .64, 1), duration: const Duration(milliseconds: 320));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    _on = !_on;
    _ctrl.animateTo(_on ? 1 : 0,
        curve: const Cubic(.34, 1.56, .64, 1));
    widget.onChanged(_on);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          // 起步拉伸：速度峰值处 width 拉长 6%，落位压回
          final velocity = (1 - (2 * t - 1).abs()); // 0..1..0
          final stretch = 1.0 + 0.06 * velocity;
          final trackW = 46.0;
          final thumbX = 3 + (trackW - 6 - 22) * t;

          return Container(
            width: trackW * stretch,
            height: 28,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: Color.lerp(LoveGirlTheme.separator, LoveGirlTheme.primary,
                  t),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: thumbX,
                  top: 3,
                  child: Transform.scale(
                    scale: 1.0 + 0.08 * velocity,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 4,
                              offset: Offset(0, 2))
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
