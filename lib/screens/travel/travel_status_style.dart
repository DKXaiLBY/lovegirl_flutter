import 'package:flutter/material.dart';

import '../../utils/lovegirl_theme.dart';

/// v4.0 旅行状态语义对（粉彩浅底 + 深字，深色走 lgSoftXxx getter 自动切换）：
/// 绿=已打卡完成 / 紫=计划中 / 蜜桃浅底=心愿单想去（蜜桃合法出口）。
/// 合并原 travel_main_screen 顶层 _statusColor（wish=蜜桃 accent）与
/// 详情弹层私有 _statusColor（wish=灰）的双色分裂；amap 模式页 _StatusBadge
/// （planned 误用绿）一并归口。
({Color bg, Color fg}) travelStatusStyle(
  BuildContext context,
  String status,
) {
  switch (status) {
    case 'visited':
      return (
        bg: context.lgSoftGreenBg,
        fg: context.lgSoftGreenText,
      );
    case 'planned':
      return (
        bg: context.lgSoftPurpleBg,
        fg: context.lgSoftPurpleText,
      );
    case 'wish':
      return (
        bg: context.lgSoftOrangeBg,
        fg: context.lgSoftOrangeText,
      );
    default:
      return (bg: context.lgBadgeBg, fg: context.lgBadgeText);
  }
}
