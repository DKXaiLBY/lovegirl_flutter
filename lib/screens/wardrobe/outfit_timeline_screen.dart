import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/wardrobe.dart';
import '../../providers/wardrobe_provider.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/lovegirl_ui.dart';
import 'outfit_capture_screen.dart';
import 'outfit_detail_screen.dart';
import 'widgets/wardrobe_widgets.dart';

/// P7 穿搭时间线【M1】：计划中（未来，最近优先）/今天/昨天/本周更早/更早；
/// 长按菜单按状态裁剪（已通过：改回待确认/删除；待确认：改为已通过/删除）
class OutfitTimelineScreen extends StatelessWidget {
  const OutfitTimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<WardrobeProvider>();
    if (p.loading && p.outfits.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (p.outfits.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          EmptyState(
            icon: Icons.photo_camera_rounded,
            illustration: kOutfitEmptyIllus,
            title: '还没有穿搭记录',
            subtitle: '拍下今天穿了什么，或从衣橱组一套',
          ),
          const SizedBox(height: 8),
          Center(
            child: LovePrimaryButton(
              text: '记录今天穿了什么',
              icon: Icons.photo_camera_rounded,
              onPressed: () => _capture(context),
            ),
          ),
        ],
      );
    }

    final groups = p.timeline;
    return RefreshIndicator(
      onRefresh: () => p.loadAll(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          for (final g in groups) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Row(
                children: [
                  Text(g.label,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: context.lgTextPrimary)),
                  const SizedBox(width: 6),
                  Text('${g.outfits.length} 条',
                      style: TextStyle(
                          fontSize: 11.5, color: context.lgTextMuted)),
                ],
              ),
            ),
            for (final o in g.outfits)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _card(context, p, o),
              ),
          ],
        ],
      ),
    );
  }

  Widget _card(BuildContext context, WardrobeProvider p, WardrobeOutfit o) {
    return GestureDetector(
      onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => OutfitDetailScreen(outfitId: o.id))),
      onLongPress: () => _menu(context, p, o),
      child: LovePaper(
        padding: const EdgeInsets.all(10),
        radius: 16,
        child: Row(
          children: [
            WnOutfitCover(o, size: 68),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.wornDate,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: context.lgTextPrimary)),
                  const SizedBox(height: 5),
                  Row(children: [
                    wnSourceBadge(o, size: 16),
                    const SizedBox(width: 6),
                    wnStatusBadge(o, p.todayStr, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      o.isPlanned(p.todayStr)
                          ? '计划'
                          : o.approved
                              ? '已通过'
                              : '待确认',
                      style: TextStyle(
                          fontSize: 11.5, color: context.lgTextSecondary),
                    ),
                  ]),
                  if (o.note?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(o.note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: context.lgTextSecondary)),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.lgTextMuted),
          ],
        ),
      ),
    );
  }

  void _menu(BuildContext context, WardrobeProvider p, WardrobeOutfit o) {
    final items = <(String, IconData, Future<String?> Function())>[
      if (!o.approved)
        (
          '改为已通过',
          Icons.check_circle_rounded,
          () => p.setOutfitStatus(o.id, '已通过'),
        )
      else
        (
          '改回待确认',
          Icons.undo_rounded,
          () => p.setOutfitStatus(o.id, '待确认'),
        ),
      (
        '删除',
        Icons.delete_rounded,
        () async {
          final ok = await wnConfirmDialog(context, '删除这条穿搭？', '删除后不可恢复');
          if (!ok) return 'cancelled';
          return p.deleteOutfit(o.id);
        },
      ),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: LovePaper(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(vertical: 8),
          radius: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (label, icon, action) in items)
                ListTile(
                  leading: Icon(icon,
                      color: label == '删除' ? const Color(0xFFE95B4E) : context.lgInk),
                  title: Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: label == '删除'
                              ? const Color(0xFFE95B4E)
                              : context.lgTextPrimary)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final err = await action();
                    if (err != null && err != 'cancelled' && context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(err)));
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _capture(BuildContext context) {
    Navigator.of(context, rootNavigator: true)
        .push(MaterialPageRoute(builder: (_) => const OutfitCaptureScreen()));
  }
}
