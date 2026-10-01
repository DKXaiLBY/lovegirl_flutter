import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/wardrobe.dart';
import '../../providers/wardrobe_provider.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/lovegirl_ui.dart';
import 'outfit_compose_screen.dart';
import 'outfit_detail_screen.dart';
import 'wardrobe_item_form_screen.dart';
import 'widgets/wardrobe_widgets.dart';

/// P3 单品详情【M1】：大图/标签/品牌价格/穿着次数/关联穿搭；
/// 底部「加入搭配」（退役置灰）+「标记为」；删除在 P4 编辑页内
class WardrobeItemDetailScreen extends StatelessWidget {
  final int itemId;

  const WardrobeItemDetailScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<WardrobeProvider>();
    final item = p.itemById(itemId);
    if (item == null) {
      return Scaffold(
        backgroundColor: context.lgBg,
        appBar: AppBar(title: const Text('单品'), backgroundColor: context.lgBg),
        body: const Center(child: Text('单品已删除或不存在')),
      );
    }
    final related = p.outfitsOfItem(itemId);

    return Scaffold(
      backgroundColor: context.lgBg,
      appBar: AppBar(
        backgroundColor: context.lgBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(item.category,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.lgTextPrimary)),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_rounded, color: context.lgTextSecondary),
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                    builder: (_) => WardrobeItemFormScreen(edit: item))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          GestureDetector(
            onTap: () => _fullscreen(context, item),
            child: LovePaper(
              padding: EdgeInsets.zero,
              radius: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: WnThumb(item.imageUrl),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (item.retired)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                const WnBadge('badge_retired', size: 16),
                const SizedBox(width: 6),
                Text('已退役 · 不出现在默认衣橱',
                    style: TextStyle(
                        fontSize: 13, color: context.lgTextSecondary)),
              ]),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (item.temperature != null) _tag(context, item.temperature!),
              if (item.color != null) _tag(context, item.color!),
              ...item.occasions.map((e) => _tag(context, e)),
              ...item.styles.map((e) => _tag(context, e)),
            ],
          ),
          const SizedBox(height: 10),
          if (p.bgObject) ...[
            // M2a 存量补抠入口（object 能力位可用时显示）
            Row(
              children: [
                Icon(Icons.auto_fix_high_rounded,
                    size: 16, color: context.lgTextSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.cutoutUrl != null
                        ? '已抠图（白底透明版，换装可用）'
                        : '还没有抠图，换装白板需要透明图',
                    style: TextStyle(
                        fontSize: 12, color: context.lgTextSecondary),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final err = await p.cutoutItem(item.id);
                    if (!context.mounted) return;
                    // err=null=成功；失败带服务端文案（修复"失败也弹抠图完成啦"）
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(err ?? '抠图完成啦'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2)));
                  },
                  child: Text(item.cutoutUrl != null ? '重新抠图' : '生成抠图'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          LovePaper(
            padding: const EdgeInsets.all(14),
            radius: 16,
            child: Column(
              children: [
                _row(context, '品牌', item.brand?.isNotEmpty == true ? item.brand! : '—'),
                _row(context, '价格',
                    item.price != null ? '¥${_priceText(item.price!)}' : '—'),
                _row(context, '穿过', '${item.wearCount} 次'),
                _row(context, '出现在穿搭', '${related.length} 条'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (related.isNotEmpty) ...[
            Text('关联穿搭',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.lgTextPrimary)),
            const SizedBox(height: 10),
            for (final o in related)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                          builder: (_) =>
                              OutfitDetailScreen(outfitId: o.id))),
                  child: LovePaper(
                    padding: const EdgeInsets.all(10),
                    radius: 16,
                    child: Row(
                      children: [
                        WnOutfitCover(o, size: 52),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.wornDate,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: context.lgTextPrimary)),
                              const SizedBox(height: 4),
                              Row(children: [
                                wnSourceBadge(o, size: 15),
                                const SizedBox(width: 6),
                                wnStatusBadge(o, p.todayStr, size: 15),
                              ]),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: context.lgTextMuted),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
      bottomSheet: SafeArea(
        child: Container(
          color: context.lgBg,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: item.retired
                      ? null
                      : () => Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  OutfitComposeScreen(preselect: [item.id]))),
                  icon: const Icon(Icons.auto_awesome_mosaic_rounded, size: 18),
                  label: const Text('加入搭配'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                        color: item.retired
                            ? context.lgSeparator
                            : context.lgInk),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _markSheet(context, p, item),
                  icon: const Icon(Icons.label_rounded, size: 18),
                  label: Text(item.retired ? '放回在柜' : '标记为'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: context.lgInk),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _priceText(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  Widget _tag(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.lgPrimarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.lgTextSecondary)),
    );
  }

  Widget _row(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
              width: 80,
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

  void _fullscreen(BuildContext context, WardrobeItem item) {
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(child: WnThumb(item.imageUrl, fit: BoxFit.contain)),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  void _markSheet(BuildContext context, WardrobeProvider p, WardrobeItem item) {
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
              ListTile(
                leading: const Icon(Icons.checkroom_rounded),
                title: const Text('在柜'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final err = await p.setItemStatus(item.id, '在柜');
                  if (err != null && context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(err)));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.archive_rounded),
                title: const Text('退役'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final err = await p.setItemStatus(item.id, '退役');
                  if (err != null && context.mounted) {
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
}
