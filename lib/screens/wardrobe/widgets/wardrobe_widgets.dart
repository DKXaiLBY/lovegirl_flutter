import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../models/wardrobe.dart';
import '../../../utils/constants.dart';
import '../../../utils/lovegirl_theme.dart';
import '../../../widgets/lovegirl_ui.dart';

/// 衣柜模块共享小组件（M1）

/// v4.0 页面浅灰渐变底（LovePage 同口径）：浅色 135° surfaceGradient，
/// 深色维持纯色 bgDark（v3.41 深色红线）；Scaffold 纯色保留兜底。
Widget wnPageBackground(BuildContext context, {required Widget child}) {
  return Container(
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
    child: child,
  );
}

/// v4.0 弹层玻璃化统一口径（radiusXl 28 / 白 72% / blur 24 / 1px 细线）：
/// 底部弹层外壳统一走此壳（深色=cardDark 72% 同成立）。
class WnGlassSheet extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final BoxConstraints? constraints;

  const WnGlassSheet({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.all(12),
    this.padding = const EdgeInsets.all(16),
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(LoveGirlTheme.radiusXl);
    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            constraints: constraints,
            padding: padding,
            decoration: BoxDecoration(
              // v4.1：72%→58%，磨砂透底感更接近参考图
              color: context.lgPaper.withValues(alpha: 0.58),
              borderRadius: radius,
              border: Border.all(color: context.lgCardBorder),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 空态插画占位（豆包正式插画 illus_empty_wardrobe / illus_empty_outfit 到位后替换）
const kWardrobeEmptyIllus = 'ui_couple';
const kOutfitEmptyIllus = 'ui_timeline';

/// PNG 角标（老设备禁 emoji，AGENTS 红线；A5 由 generate 脚本产出）
/// badge_pending 橙点 / badge_approved 绿勾 / badge_planned 蓝钟 /
/// src_photo 实拍 / src_combo 组合 / badge_retired 退役
class WnBadge extends StatelessWidget {
  final String name;
  final double size;

  const WnBadge(this.name, {super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/icons/$name.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

/// 状态/计划角标：日期在未来一律"计划"蓝钟（叠加态优先），否则按真实状态
Widget wnStatusBadge(WardrobeOutfit o, String today, {double size = 18}) =>
    WnBadge(o.isPlanned(today) ? 'badge_planned' : o.approved ? 'badge_approved' : 'badge_pending', size: size);

Widget wnSourceBadge(WardrobeOutfit o, {double size = 18}) =>
    WnBadge(o.isCombo ? 'src_combo' : 'src_photo', size: size);

class WnThumb extends StatelessWidget {
  final String? path;
  final double? size;
  final BoxFit fit;

  const WnThumb(this.path, {super.key, this.size, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final url = wnImgUrl(path, baseUrl: AppConstants.baseUrl);
    if (url.isEmpty) {
      return Container(
        width: size,
        height: size,
        color: context.lgPrimarySoft,
        child: Icon(Icons.checkroom_rounded, color: context.lgTextMuted),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: fit,
      memCacheWidth: 400,
      placeholder: (_, __) => Container(color: context.lgPrimarySoft),
      errorWidget: (_, __, ___) => Container(
        color: context.lgPrimarySoft,
        child: Icon(Icons.checkroom_rounded, color: context.lgTextMuted),
      ),
    );
  }
}

/// 标签胶囊（选中=黑底白字，未选=badgeBg 浅灰底细线）
class WnChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const WnChip(this.label, {super.key, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          // v4.0：未选态从透明改中性徽章浅灰（lgBadgeBg，深色=primarySoftDark），
          // 配 1px 细线描边（参考图③黑胶囊选中同款）
          color: selected ? context.lgInk : context.lgBadgeBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? context.lgInk : context.lgCardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.white : context.lgTextSecondary,
          ),
        ),
      ),
    );
  }
}

/// 一组单选/多选胶囊
class WnChipGroup extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const WnChipGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map((o) => WnChip(o, selected: selected.contains(o), onTap: () => onToggle(o)))
          .toList(),
    );
  }
}

/// 单品卡（网格 + 多选）
class WnItemCard extends StatelessWidget {
  final WardrobeItem item;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const WnItemCard({
    super.key,
    required this.item,
    required this.selecting,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: LovePaper(
        padding: EdgeInsets.zero,
        radius: LoveGirlTheme.radius,
        border: selected ? Border.all(color: context.lgInk, width: 2) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(LoveGirlTheme.radius)),
                    child: WnThumb(item.thumbnailUrl ?? item.imageUrl),
                  ),
                ),
                if (selecting)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? context.lgInk : Colors.white,
                        border: Border.all(color: context.lgInk, width: 1.5),
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                          : null,
                    ),
                  ),
                if (item.retired)
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('退役',
                          style: TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Text(
                item.brand?.isNotEmpty == true ? item.brand! : item.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.lgTextPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 穿搭封面：实拍图 / 组合缩略图叠排 / 全删灰底
class WnOutfitCover extends StatelessWidget {
  final WardrobeOutfit outfit;
  final double size;

  const WnOutfitCover(this.outfit, {super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    if (!outfit.isCombo && outfit.photoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: WnThumb(outfit.photoUrl, size: size),
      );
    }
    final alive = outfit.items.where((e) => !e.deleted).toList();
    if (alive.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: context.lgPrimarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          '单品已删除',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 9, color: context.lgTextMuted),
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < alive.length && i < 3; i++)
            Positioned(
              left: i * (size / 3.2),
              top: i * 3.0,
              child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: context.lgPaper, width: 1.5),
      ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: WnThumb(alive[i].thumbnailUrl, size: size * 0.62),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<bool> wnConfirmDialog(BuildContext context, String title, String body,
    {String confirmText = '删除'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(ctx).dialogBackgroundColor,
      // v4.0 弹层大圆角 + 1px 细线（参考图⑦口径）
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LoveGirlTheme.radiusXl),
        side: BorderSide(color: ctx.lgCardBorder),
      ),
      title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      content: Text(body, style: const TextStyle(fontSize: 14)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText,
              style: const TextStyle(
                  color: LoveGirlTheme.red, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return ok == true;
}
