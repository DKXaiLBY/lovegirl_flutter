import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/wardrobe.dart';
import '../../providers/wardrobe_provider.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/lovegirl_ui.dart';
import 'outfit_capture_screen.dart';
import 'outfit_compose_screen.dart';
import 'wardrobe_item_detail_screen.dart';
import 'widgets/wardrobe_widgets.dart';

/// P9 穿搭详情【M1】：大图/组合单品横排（软删=灰占位不可点）/元信息/状态流转
/// 未来日期一律显示"计划"蓝钟，操作按钮按真实状态给出（§3 叠加态规则）
class OutfitDetailScreen extends StatelessWidget {
  final int outfitId;

  const OutfitDetailScreen({super.key, required this.outfitId});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<WardrobeProvider>();
    final o = p.outfits.where((e) => e.id == outfitId).firstOrNull;
    if (o == null) {
      return Scaffold(
        backgroundColor: context.lgBg,
        appBar: AppBar(title: const Text('穿搭'), backgroundColor: context.lgBg),
        body: const Center(child: Text('这条穿搭已删除')),
      );
    }
    final planned = o.isPlanned(p.todayStr);

    return Scaffold(
      backgroundColor: context.lgBg,
      appBar: AppBar(
        backgroundColor: context.lgBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(o.wornDate,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.lgTextPrimary)),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_rounded, color: const Color(0xFFE95B4E)),
            onPressed: () => _delete(context, p, o),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (planned)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                const WnBadge('badge_planned', size: 16),
                const SizedBox(width: 6),
                Text('计划 · 将在 ${o.wornDate} 穿',
                    style: TextStyle(
                        fontSize: 13, color: context.lgTextSecondary)),
              ]),
            ),
          if (!o.isCombo && o.photoUrl != null)
            LovePaper(
              padding: EdgeInsets.zero,
              radius: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: WnThumb(o.photoUrl),
                ),
              ),
            )
          else
            _comboRow(context, o),
          const SizedBox(height: 16),
          LovePaper(
            padding: const EdgeInsets.all(14),
            radius: 16,
            child: Column(
              children: [
                _row(context, '来源', o.source),
                _row(context, '状态',
                    planned ? '计划（${o.status}）' : o.status),
                _row(context, '备注', o.note?.isNotEmpty == true ? o.note! : '—'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (!o.approved)
            LovePrimaryButton(
              text: '通过这套',
              icon: Icons.check_circle_rounded,
              onPressed: () => _setStatus(context, p, o, '已通过'),
            ),
          if (!o.approved) const SizedBox(height: 10),
          if (o.approved)
            OutlinedButton.icon(
              onPressed: () => _setStatus(context, p, o, '待确认'),
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: const Text('改回待确认'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: context.lgInk),
              ),
            ),
          if (o.approved) const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _edit(context, o),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('继续编辑'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: context.lgInk),
            ),
          ),
        ],
      ),
    );
  }

  Widget _comboRow(BuildContext context, WardrobeOutfit o) {
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final s in o.items)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: s.deleted
                    ? null // 已删除占位不可点（§4.10）
                    : () => Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                WardrobeItemDetailScreen(itemId: s.id))),
                child: s.deleted
                    ? Container(
                        width: 96,
                        decoration: BoxDecoration(
                          color: context.lgPrimarySoft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: context.lgSeparator,
                              style: BorderStyle.solid),
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          '已删除\n·${s.category ?? '单品'}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              color: context.lgTextMuted,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: context.lgTextMuted),
                        ),
                      )
                    : Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                                width: 96,
                                height: 96,
                                child: WnThumb(s.thumbnailUrl)),
                          ),
                          const SizedBox(height: 4),
                          Text(s.brand ?? s.category ?? '',
                              style: TextStyle(
                                  fontSize: 10.5,
                                  color: context.lgTextSecondary)),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 64,
              child: Text(k,
                  style: TextStyle(
                      fontSize: 13, color: context.lgTextSecondary))),
          Expanded(
            child: Text(v,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.lgTextPrimary)),
          ),
        ],
      ),
    );
  }

  Future<void> _setStatus(
      BuildContext context, WardrobeProvider p, WardrobeOutfit o, String status) async {
    final err = await p.setOutfitStatus(o.id, status);
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  void _edit(BuildContext context, WardrobeOutfit o) {
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
        builder: (_) => o.isCombo
            ? OutfitComposeScreen(edit: o)
            : OutfitCaptureScreen(edit: o)));
  }

  Future<void> _delete(
      BuildContext context, WardrobeProvider p, WardrobeOutfit o) async {
    final ok = await wnConfirmDialog(context, '删除这条穿搭？', '删除后不可恢复');
    if (!ok) return;
    final err = await p.deleteOutfit(o.id);
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    Navigator.of(context).pop();
  }
}
