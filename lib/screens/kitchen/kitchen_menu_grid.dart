import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../providers/kitchen_provider.dart';
import '../../utils/constants.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/rebuild_controls.dart';

/// A photo menu made only from the selected kitchen's actual dishes.
class KitchenMenuGrid extends StatefulWidget {
  final KitchenProvider kitchen;
  final VoidCallback onOpenCart;
  const KitchenMenuGrid(
      {super.key, required this.kitchen, required this.onOpenCart});
  @override
  State<KitchenMenuGrid> createState() => _KitchenMenuGridState();
}

class _KitchenMenuGridState extends State<KitchenMenuGrid> {
  final _search = TextEditingController();
  String _category = '全部';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kitchen = widget.kitchen;
    final categories = [
      '全部',
      ...kitchen.partnerDishes.map((d) => d.category).toSet()
    ];
    final selected = categories.contains(_category) ? _category : '全部';
    final query = _search.text.trim().toLowerCase();
    final dishes = kitchen.partnerDishes
        .where((dish) =>
            (selected == '全部' || dish.category == selected) &&
            '${dish.name} ${dish.description ?? ''} ${dish.category}'
                .toLowerCase()
                .contains(query))
        .toList();
    return Stack(children: [
      Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: RebuildGlass(
              radius: 28,
              child: TextField(
                controller: _search,
                style:
                    TextStyle(fontSize: 14, height: 1.2, color: context.lgInk),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '找一道想吃的菜',
                  hintStyle: TextStyle(
                      fontSize: 14, height: 1.2, color: context.lgTextMuted),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清除搜索',
                          onPressed: () => setState(_search.clear),
                          icon: const Icon(Icons.close_rounded)),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              )),
        ),
        SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => RebuildGlass(
                radius: 26,
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(76, 48),
                    backgroundColor: selected == categories[i]
                        ? context.lgPaper.withAlpha(170)
                        : Colors.transparent,
                    foregroundColor: context.lgInk,
                    textStyle: TextStyle(
                        fontWeight: selected == categories[i]
                            ? FontWeight.w700
                            : FontWeight.w400),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _category = categories[i]);
                  },
                  child: Text(categories[i]),
                ),
              ),
            )),
        Expanded(
            child: dishes.isEmpty
                ? Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.restaurant_menu_outlined,
                                size: 40, color: context.lgTextMuted),
                            const SizedBox(height: 12),
                            Text(query.isEmpty ? 'TA 还没有添加这类菜' : '没有找到这道菜',
                                textAlign: TextAlign.center),
                            if (query.isNotEmpty || selected != '全部')
                              TextButton(
                                  onPressed: () => setState(() {
                                        _search.clear();
                                        _category = '全部';
                                      }),
                                  child: const Text('查看全部菜单')),
                          ],
                        )))
                : ListView.separated(
                    key: const PageStorageKey('kitchen-photo-menu'),
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 110),
                    itemCount: (dishes.length / 2).ceil() + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, row) {
                      if (row == (dishes.length / 2).ceil()) {
                        return RebuildGlass(
                            radius: 22,
                            child: ListTile(
                              leading: const Icon(Icons.notes_outlined),
                              title: const Text('口味与备注'),
                              subtitle: Text(kitchen.cartCount > 0
                                  ? '确认这一餐时一起告诉主厨'
                                  : '先选菜，再添加口味和开饭安排'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: kitchen.cartCount > 0
                                  ? widget.onOpenCart
                                  : null,
                            ));
                      }
                      final left = dishes[row * 2];
                      final right = row * 2 + 1 < dishes.length
                          ? dishes[row * 2 + 1]
                          : null;
                      return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: _MenuPhotoCard(
                                    dish: left, kitchen: kitchen)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: right == null
                                    ? const SizedBox.shrink()
                                    : _MenuPhotoCard(
                                        dish: right, kitchen: kitchen)),
                          ]);
                    },
                  )),
      ]),
      Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: RebuildGlass(
            radius: 30,
            padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
            child: Row(children: [
              const Icon(Icons.restaurant_outlined, size: 24),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      kitchen.cartCount > 0
                          ? '已选 ${kitchen.cartCount} 份'
                          : '挑几道想吃的菜',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600))),
              FilledButton(
                style: rebuildFilledStyle(context),
                onPressed: kitchen.cartCount > 0 && !kitchen.placingOrder
                    ? widget.onOpenCart
                    : null,
                child: const Text('确认这餐'),
              ),
            ]),
          )),
    ]);
  }
}

class _MenuPhotoCard extends StatelessWidget {
  final KitchenDish dish;
  final KitchenProvider kitchen;
  const _MenuPhotoCard({required this.dish, required this.kitchen});

  Widget _photo(BuildContext context) => dish.photoUrl?.isNotEmpty == true
      ? Image.network(kitchenPhotoUrl(dish.photoUrl!, AppConstants.baseUrl),
          fit: BoxFit.cover,
          cacheWidth: 600,
          errorBuilder: (_, __, ___) => _missing(context))
      : _missing(context);
  Widget _missing(BuildContext context) => ColoredBox(
      color: context.lgPrimarySoft,
      child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.restaurant_outlined, color: context.lgTextMuted, size: 32),
        const SizedBox(height: 6),
        Text('还没有照片',
            style: TextStyle(fontSize: 11, color: context.lgTextMuted)),
      ])));

  void _details(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.lgPaper,
      builder: (context) => SafeArea(
          child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child:
                        AspectRatio(aspectRatio: 1.2, child: _photo(context))),
                const SizedBox(height: 16),
                Text(dish.name,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(dish.description?.isNotEmpty == true
                    ? dish.description!
                    : dish.category),
                const SizedBox(height: 20),
                Text('这道菜还没有记录食材与做法',
                    style: TextStyle(color: context.lgTextMuted)),
                const SizedBox(height: 12),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('回到菜单')),
              ],
            )),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qty = kitchen.cart[dish.id] ?? 0;
    return Material(
      key: ValueKey('kitchen-dish-${dish.id}'),
      color: context.lgPaper.withAlpha(context.lgIsDark ? 220 : 210),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
            onTap: () => _details(context),
            child: Semantics(
                button: true,
                excludeSemantics: true,
                label: '查看${dish.name}详情',
                child: AspectRatio(aspectRatio: 1.1, child: _photo(context)))),
        Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 3),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dish.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                  dish.description?.isNotEmpty == true
                      ? dish.description!
                      : dish.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.lgTextMuted)),
            ])),
        Padding(
            padding: const EdgeInsets.fromLTRB(7, 0, 7, 6),
            child: Row(children: [
              if (qty > 0)
                RebuildGlassButton(
                    label: '减少${dish.name}',
                    onPressed: kitchen.placingOrder
                        ? null
                        : () => kitchen.removeFromCart(dish.id),
                    icon: Icons.remove_rounded),
              Expanded(
                  child: qty > 0
                      ? Text('$qty',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600))
                      : const SizedBox.shrink()),
              RebuildGlassButton(
                  label: qty >= 9 ? '每道菜最多9份' : '增加${dish.name}',
                  onPressed: qty >= 9 || kitchen.placingOrder
                      ? null
                      : () {
                          kitchen.addToCart(dish.id);
                        },
                  icon: Icons.add_rounded),
            ])),
      ]),
    );
  }
}
