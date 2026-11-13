import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/wardrobe.dart';
import '../../providers/wardrobe_provider.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/lovegirl_ui.dart';
import '../../widgets/rebuild_controls.dart';
import 'outfit_compose_screen.dart';
import 'wardrobe_dimension_sheet.dart';
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
  late final _search = TextEditingController(
      text: context.read<WardrobeProvider>().filter.query);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _selecting => _selected.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<WardrobeProvider>();

    if (p.loading && p.items.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (!p.hasAnyItem && p.error == null) {
      return RefreshIndicator(onRefresh: p.loadAll, child: _empty());
    }
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting && mounted) setState(() => _selected.clear());
      },
      child: Stack(children: [
        RefreshIndicator(
          onRefresh: p.loadAll,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                sliver: SliverToBoxAdapter(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (p.error != null)
                          ListTile(
                            title: Text(p.error!),
                            trailing: TextButton(
                                onPressed: p.loadAll, child: const Text('重试')),
                          ),
                        if (p.loading) const LinearProgressIndicator(),
                        if (p.hasAnyItem) ...[
                          TextField(
                            controller: _search,
                            onChanged: (value) {
                              p.filter.query = value.trim();
                              p.applyFilter();
                            },
                            decoration: InputDecoration(
                              hintText: '搜索品牌、类别或颜色',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: p.filter.query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: '清除搜索',
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        _search.clear();
                                        p.filter.query = '';
                                        p.applyFilter();
                                      },
                                    ),
                              filled: true,
                              fillColor: context.lgPaper,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _toolbar(p),
                          if (p.anyVisible) const WardrobeDimensionRow(),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(children: [
                              _catChip(p, '全部', null),
                              for (final category in WardrobeTax.categories)
                                _catChip(p, category, category),
                            ]),
                          ),
                          if (!p.anyVisible) _noMatch(p),
                        ],
                      ]),
                ),
              ),
              for (final entry in p.groupedItems.entries)
                ..._section(entry.key, entry.value),
              const SliverToBoxAdapter(child: SizedBox(height: 116)),
            ],
          ),
        ),
        if (_selecting) _actionBar(p),
      ]),
    );
  }

  Widget _empty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
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
    final capsuleActive =
        p.todayBand != null && p.filter.temperature == p.todayBand;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('${p.filteredItems.length} 件衣物',
            style: TextStyle(color: context.lgTextSecondary)),
        RebuildGlassButton(
          label: p.filter.isDefault ? '筛选' : '已筛选',
          icon: Icons.tune,
          showLabel: true,
          onPressed: () async {
            await showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => const WardrobeFilterSheet(),
            );
            if (mounted && _search.text.trim() != p.filter.query) {
              _search.text = p.filter.query;
            }
          },
        ),
        if (p.todayTemp != null && p.todayBand != null)
          RebuildChoiceChip(
            label: Text('今天 ${p.todayTemp}°C · ${p.todayBand}'),
            selected: capsuleActive,
            onSelected: (_) {
              p.filter.temperature = capsuleActive ? null : p.todayBand;
              p.applyFilter();
            },
          ),
      ],
    );
  }

  Widget _noMatch(WardrobeProvider p) {
    return LovePaper(
      padding: const EdgeInsets.symmetric(vertical: 28),
      radius: LoveGirlTheme.radiusLg,
      child: Column(
        children: [
          Text('没有匹配的衣服',
              style: TextStyle(fontSize: 14, color: context.lgTextSecondary)),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              _search.clear();
              p.filter.reset();
              p.applyFilter();
            },
            child: const Text('清除筛选'),
          ),
        ],
      ),
    );
  }

  List<Widget> _section(String category, List<WardrobeItem> items) {
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 5, 16, 10),
          child: Row(children: [
            Expanded(
                child: Text(category,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ))),
            Text('${items.length} 件',
                style: TextStyle(color: context.lgTextSecondary)),
          ]),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        sliver: SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: scale > 1.4 ? .69 : .82,
          ),
          itemCount: items.length,
          itemBuilder: (_, index) {
            final item = items[index];
            return WnItemCard(
              key: ValueKey(item.id),
              item: item,
              selecting: _selecting,
              selected: _selected.contains(item.id),
              onTap: () => _selecting ? _toggle(item.id) : _openDetail(item.id),
              onLongPress: () => _toggle(item.id),
            );
          },
        ),
      ),
    ];
  }

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
            borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
            boxShadow: LoveGirlTheme.cardShadowElevated(),
          ),
          child: Row(
            children: [
              Text('已选 ${_selected.length}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
              const Spacer(),
              _action('加入搭配', Icons.auto_awesome_mosaic_rounded,
                  () => _addToOutfit(p)),
              _action('退役', Icons.archive_rounded, () => _retire(p)),
              _action('删除', Icons.delete_rounded, () => _deleteSelected(p)),
            ],
          ),
          // 底部浮条操作
        ),
      ),
    );
  }

  void _toggle(int id) => setState(() {
        if (!_selected.add(id)) _selected.remove(id);
      });

  Widget _action(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
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
    final selectedItems =
        ids.map((e) => p.itemById(e)).whereType<WardrobeItem>().toList();
    if (selectedItems.any((e) => e.retired)) {
      _toast('选里有退役单品，去掉再加吧');
      return;
    }
    setState(() => _selected.clear());
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => OutfitComposeScreen(preselect: ids)));
  }

  Future<void> _retire(WardrobeProvider p) async {
    final ids = _selected.toList();
    final ok = await wnConfirmDialog(
        context, '退役这 ${ids.length} 件？', '退役后不再出现在默认衣橱里（筛选器可查看，可恢复）',
        confirmText: '退役');
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
    final ok = await wnConfirmDialog(
        context,
        '删除 ${ids.length} 件？',
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

  /// MIROIR 化分类 chip：点击预填 filter.category（全部=null）
  Widget _catChip(WardrobeProvider p, String label, String? category) {
    final selected = p.filter.category == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: RebuildChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          p.filter.category = category;
          p.applyFilter();
        },
      ),
    );
  }

  void _openForm() {
    Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => const WardrobeItemFormScreen()));
  }

  void _openDetail(int id) {
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
        builder: (_) => WardrobeItemDetailScreen(itemId: id)));
  }
}
