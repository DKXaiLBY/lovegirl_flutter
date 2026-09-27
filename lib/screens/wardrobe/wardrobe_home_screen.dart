import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/wardrobe.dart';
import '../../providers/wardrobe_provider.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/lovegirl_ui.dart';
import 'outfit_compose_screen.dart';
import 'wardrobe_filter_sheet.dart';
import 'wardrobe_item_detail_screen.dart';
import 'wardrobe_item_form_screen.dart';
import 'widgets/wardrobe_widgets.dart';

/// P1 衣橱主页【M1】：8 类分节 2 列网格（空节隐藏、节内添加时间倒序）、
/// 「今天」胶囊、筛选、多选（加入搭配/退役/删除）
class WardrobeHomeScreen extends StatefulWidget {
  const WardrobeHomeScreen({super.key});

  @override
  State<WardrobeHomeScreen> createState() => _WardrobeHomeScreenState();
}

class _WardrobeHomeScreenState extends State<WardrobeHomeScreen> {
  final Set<int> _selected = {};

  bool get _selecting => _selected.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<WardrobeProvider>();

    if (p.loading && p.items.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (!p.hasAnyItem) {
      return _empty(p);
    }
    return PopScope(
      // 边界 9：多选模式系统返回键先退多选
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting && mounted) setState(() => _selected.clear());
      },
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => p.loadAll(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
              children: [
                _toolbar(p),
                const SizedBox(height: 12),
                if (!p.anyVisible) _noMatch(p),
                for (final entry in p.groupedItems.entries)
                  _section(p, entry.key, entry.value),
              ],
            ),
          ),
          if (_selecting) _actionBar(p),
        ],
      ),
    );
  }

  Widget _empty(WardrobeProvider p) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        EmptyState(
          icon: Icons.checkroom_rounded,
          illustration: kWardrobeEmptyIllus,
          title: '衣橱还空着',
          subtitle: '拍下第一件衣服，开始你们的穿搭档案',
        ),
        const SizedBox(height: 8),
        Center(
          child: LovePrimaryButton(
            text: '放入第一件衣服',
            icon: Icons.add_rounded,
            onPressed: () => _openForm(),
          ),
        ),
      ],
    );
  }

  Widget _toolbar(WardrobeProvider p) {
    final capsuleActive = p.todayBand != null && p.filter.temperature == p.todayBand;
    return Row(
      children: [
        if (p.todayTemp != null && p.todayBand != null)
          GestureDetector(
            onTap: () {
              // Q6：一键预填今天温度档（再点取消）
              p.filter.temperature = capsuleActive ? null : p.todayBand;
              p.applyFilter();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: capsuleActive ? context.lgInk : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: capsuleActive ? context.lgInk : context.lgSeparator,
                ),
              ),
              child: Text(
                '今天 ${p.todayTemp}°C · ${p.todayBand}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: capsuleActive ? Colors.white : context.lgTextPrimary,
                ),
              ),
            ),
          ),
        const Spacer(),
        Text(
          '${p.filteredItems.length} 件',
          style: TextStyle(fontSize: 12, color: context.lgTextSecondary),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => const WardrobeFilterSheet(),
          ),
          child: LovePill(
            text: p.filter.isDefault ? '筛选' : '已筛选',
            icon: Icons.tune_rounded,
            color: context.lgInk,
          ),
        ),
      ],
    );
  }

  Widget _noMatch(WardrobeProvider p) {
    return LovePaper(
      padding: const EdgeInsets.symmetric(vertical: 28),
      radius: 18,
      child: Column(
        children: [
          Text('没有匹配的衣服',
              style: TextStyle(fontSize: 14, color: context.lgTextSecondary)),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              p.filter.reset();
              p.applyFilter();
            },
            child: const Text('清除筛选'),
          ),
        ],
      ),
    );
  }

  Widget _section(WardrobeProvider p, String category, List<WardrobeItem> list) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(category,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.lgTextPrimary)),
              const SizedBox(width: 6),
              Text('${list.length} 件',
                  style: TextStyle(
                      fontSize: 12, color: context.lgTextMuted)),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final it = list[i];
              return WnItemCard(
                item: it,
                selecting: _selecting,
                selected: _selected.contains(it.id),
                onTap: () {
                  if (_selecting) {
                    _toggle(it.id);
                  } else {
                    _openDetail(it.id);
                  }
                },
                onLongPress: () => _toggle(it.id),
              );
            },
          ),
        ],
      ),
    );
  }

  void _toggle(int id) => setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));

  Widget _actionBar(WardrobeProvider p) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: context.lgInk,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Text('已选 ${_selected.length}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
              const Spacer(),
              _action('加入搭配', Icons.auto_awesome_mosaic_rounded, () => _addToOutfit(p)),
              _action('退役', Icons.archive_rounded, () => _retire(p)),
              _action('删除', Icons.delete_rounded, () => _deleteSelected(p)),
            ],
          ),
          // 底部浮条操作
        ),
      ),
    );
  }

  Widget _action(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Future<void> _addToOutfit(WardrobeProvider p) async {
    final ids = _selected.toList();
    if (ids.length > 8) {
      _toast('最多 8 件，先去掉 ${ids.length - 8} 件吧');
      return;
    }
    final selectedItems = ids.map((e) => p.itemById(e)).whereType<WardrobeItem>().toList();
    if (selectedItems.any((e) => e.retired)) {
      _toast('选里有退役单品，去掉再加吧');
      return;
    }
    setState(() => _selected.clear());
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true)
        .push(MaterialPageRoute(builder: (_) => OutfitComposeScreen(preselect: ids)));
  }

  Future<void> _retire(WardrobeProvider p) async {
    final ids = _selected.toList();
    final ok = await wnConfirmDialog(context, '退役这 ${ids.length} 件？',
        '退役后不再出现在默认衣橱里（筛选器可查看，可恢复）', confirmText: '退役');
    if (!ok) return;
    for (final id in ids) {
      await p.setItemStatus(id, '退役');
    }
    setState(() => _selected.clear());
  }

  Future<void> _deleteSelected(WardrobeProvider p) async {
    final ids = _selected.toList();
    var totalRefs = 0;
    for (final id in ids) {
      totalRefs += p.outfitsOfItem(id).length;
    }
    final ok = await wnConfirmDialog(context, '删除 ${ids.length} 件？',
        totalRefs > 0
            ? '它们出现在 $totalRefs 条穿搭中，删除后那些穿搭将显示「单品已删除」占位'
            : '删除后不可恢复，确定吗？');
    if (!ok) return;
    for (final id in ids) {
      await p.deleteItem(id);
    }
    setState(() => _selected.clear());
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openForm() {
    Navigator.of(context, rootNavigator: true)
        .push(MaterialPageRoute(builder: (_) => const WardrobeItemFormScreen()));
  }

  void _openDetail(int id) {
    Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => WardrobeItemDetailScreen(itemId: id)));
  }
}
