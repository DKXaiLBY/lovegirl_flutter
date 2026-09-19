import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/kitchen_provider.dart';
import '../../utils/constants.dart';
import '../../utils/lovegirl_theme.dart';
import '../../utils/motion.dart';
import '../../widgets/lovegirl_ui.dart';
import '../couple/couple_binding_screen.dart';
import '../../widgets/app_icon.dart';

/// 情侣厨房：TA 的菜单点菜 / 我的厨房 / 开饭记录
class KitchenScreen extends StatelessWidget {
  const KitchenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: context.read<KitchenProvider>(),
      child: const _KitchenView(),
    );
  }
}

class _KitchenView extends StatefulWidget {
  const _KitchenView();

  @override
  State<_KitchenView> createState() => _KitchenViewState();
}

class _KitchenViewState extends State<_KitchenView>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<KitchenProvider>().refreshAll();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.lgBg,
      body: SafeArea(
        bottom: false,
        child: Consumer<KitchenProvider>(builder: (context, kitchen, _) {
          return Column(
            children: [
              _buildHeader(context, kitchen),
              Expanded(
                child: kitchen.loading && kitchen.mine.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : !kitchen.bound
                        ? _UnboundView()
                        : Column(
                            children: [
                              Padding(
                                padding:
                                    EdgeInsets.fromLTRB(16, 4, 16, 8),
                                child: LoveSectionTitle(
                                    title: '今晚想吃什么？由 TA 掌勺'),
                              ),
                              TabBar(
                                controller: _tab,
                                labelColor: context.lgInk,
                                unselectedLabelColor:
                                    context.lgTextMuted,
                                indicatorColor: context.lgInk,
                                indicatorSize: TabBarIndicatorSize.label,
                                labelStyle: const TextStyle(
                                    fontWeight: FontWeight.w800),
                                tabs: const [
                                  Tab(text: '点菜单'),
                                  Tab(text: '我的厨房'),
                                  Tab(text: '开饭记录'),
                                ],
                              ),
                              Expanded(
                                child: TabBarView(
                                  controller: _tab,
                                  children: [
                                    _MenuTab(kitchen: kitchen),
                                    _MyKitchenTab(kitchen: kitchen),
                                    _RecordsTab(kitchen: kitchen),
                                  ],
                                ),
                              ),
                            ],
                          ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, KitchenProvider kitchen) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: AppIcon('back'),
            color: context.lgTextPrimary,
          ),
          SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '情侣厨房 ❤',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    color: context.lgTextPrimary,
                  ),
                ),
                Text(
                  kitchen.bound && kitchen.partnerName != null
                      ? '主厨：${kitchen.partnerName} · 想吃就点'
                      : '把会做的菜挂上菜单，等 TA 来点',
                  style: TextStyle(
                      fontSize: 12, color: context.lgTextMuted),
                ),
              ],
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () => _openOrders(context),
                icon: AppIcon('ticket'),
                color: context.lgTextPrimary,
              ),
              if (kitchen.incomingNew > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: LoveGirlTheme.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${kitchen.incomingNew}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _openOrders(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => KitchenOrdersScreen()),
    );
  }
}

// ================= 未绑定引导 =================

class _UnboundView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                  color: context.lgPrimarySoft, shape: BoxShape.circle),
              child: Icon(Icons.restaurant_menu_rounded,
                  size: 42, color: context.lgInk),
            ),
            const SizedBox(height: 20),
            Text(
              '绑定 TA，菜单才有食客',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.lgTextPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              '情侣厨房需要先绑定伴侣\n绑定后你们可以互相挂菜单、点菜、开火',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.lgTextMuted),
            ),
            const SizedBox(height: 24),
            LovePrimaryButton(
              text: '去绑定伴侣',
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const CoupleBindingScreen()));
                if (context.mounted) {
                  context.read<KitchenProvider>().refreshAll();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ================= 点菜单（TA 的菜单） =================

const List<String> _presetCategories = [
  '硬菜',
  '家常菜',
  '汤羹',
  '主食',
  '甜品',
  '夜宵',
  '饮品',
];

class _MenuTab extends StatefulWidget {
  final KitchenProvider kitchen;
  const _MenuTab({required this.kitchen});

  @override
  State<_MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<_MenuTab> {
  String _category = '全部';

  List<String> get _categories {
    final names =
        widget.kitchen.partnerDishes.map((d) => d.category).toSet();
    return ['全部', ..._presetCategories.where(names.contains), ...names.where((c) => !_presetCategories.contains(c))];
  }

  List<KitchenDish> get _filtered {
    final dishes = widget.kitchen.partnerDishes;
    if (_category == '全部') return dishes;
    return dishes.where((d) => d.category == _category).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final dishes = _filtered;
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: dishes.isEmpty
                  ? _MenuEmpty(partnerName: widget.kitchen.partnerName)
                  : Row(
                      children: [
                        _CategoryRail(
                          categories: _categories,
                          selected: _category,
                          onSelected: (c) => setState(() => _category = c),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding:
                                EdgeInsets.fromLTRB(12, 12, 16, 96),
                            itemCount: dishes.length,
                            separatorBuilder: (_, __) =>
                                SizedBox(height: 10),
                            itemBuilder: (context, i) => StaggerIn(
                              index: i,
                              child: _DishCard(
                                dish: dishes[i],
                                onAdd: () {
                                  widget.kitchen.addToCart(dishes[i].id);
                                  HapticFeedback.selectionClick();
                                },
                                qty: widget.kitchen.cart[dishes[i].id] ?? 0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: _CartBar(
            count: widget.kitchen.cartCount,
            total: widget.kitchen.cartTotal,
            onOpen: widget.kitchen.cartCount > 0 ? _openCart : null,
          ),
        ),
      ],
    );
  }

  void _openCart() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CartSheet(),
    );
  }
}

class _MenuEmpty extends StatelessWidget {
  final String? partnerName;
  const _MenuEmpty({this.partnerName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🍳', style: TextStyle(fontSize: 52)),
          SizedBox(height: 12),
          Text(
            '${partnerName ?? 'TA'} 的菜单还是空的',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.lgTextPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            '提醒 TA 把会做的菜挂上来吧',
            style: TextStyle(fontSize: 12, color: context.lgTextMuted),
          ),
        ],
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  const _CategoryRail({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      color: context.lgPaperWarm,
      child: ListView.builder(
        itemCount: categories.length,
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemBuilder: (context, i) {
          final c = categories[i];
          final active = c == selected;
          return InkWell(
            onTap: () => onSelected(c),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: active ? context.lgBg : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    width: 3,
                    color: active
                        ? context.lgInk
                        : Colors.transparent,
                  ),
                ),
              ),
              child: Text(
                c,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: active
                      ? context.lgInk
                      : context.lgTextSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DishCard extends StatelessWidget {
  final KitchenDish dish;
  final VoidCallback onAdd;
  final int qty;

  const _DishCard({
    required this.dish,
    required this.onAdd,
    required this.qty,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.lgPaper,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(14),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 64,
              height: 64,
              child: dish.photoUrl != null
                  ? Image.network(
                      kitchenPhotoUrl(dish.photoUrl!, AppConstants.baseUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _emojiBox(context),
                    )
                  : _emojiBox(context),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dish.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.lgTextPrimary),
                ),
                if (dish.description != null &&
                    dish.description!.isNotEmpty) ...[
                  SizedBox(height: 3),
                  Text(
                    dish.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: context.lgTextMuted),
                  ),
                ],
                SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      dish.price > 0 ? '¥${dish.price}' : '心意价',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: LoveGirlTheme.red),
                    ),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '· ${dish.category}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: context.lgTextMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          qty > 0
              ? Container(
                  decoration: BoxDecoration(
                    color: context.lgPrimarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context
                            .read<KitchenProvider>()
                            .removeFromCart(dish.id),
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: Icon(Icons.remove_rounded,
                              size: 16, color: context.lgInk),
                        ),
                      ),
                      SizedBox(
                        width: 22,
                        child: Text('$qty',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: context.lgInk)),
                      ),
                      GestureDetector(
                        onTap: onAdd,
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: Icon(Icons.add_rounded,
                              size: 16, color: context.lgInk),
                        ),
                      ),
                    ],
                  ),
                )
              : _AddButton(onTap: onAdd),
        ],
      ),
    );
  }

  Widget _emojiBox(context) => Container(
        color: context.lgPrimarySoft,
        alignment: Alignment.center,
        child: Text(dish.emoji, style: const TextStyle(fontSize: 34)),
      );
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
            color: context.lgInk, shape: BoxShape.circle),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  final int count;
  final int total;
  final VoidCallback? onOpen;

  const _CartBar({
    required this.count,
    required this.total,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
        decoration: BoxDecoration(
          color: count > 0 ? context.lgTextPrimary : context.lgTextMuted,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(40),
                blurRadius: 16,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.shopping_bag_rounded,
                    color: Colors.white, size: 24),
                if (count > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: LoveGirlTheme.red, shape: BoxShape.circle),
                      child: Text('$count',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                count > 0 ? '合计 ¥$total' : '看看 TA 能做什么菜',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14),
              ),
            ),
            Text(
              count > 0 ? '去下单' : '先逛逛',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14),
            ),
            SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

// ================= 购物车下单 =================

class _CartSheet extends StatefulWidget {
  const _CartSheet();

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kitchen = context.watch<KitchenProvider>();
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.lgBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: context.lgSeparator,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            SizedBox(height: 14),
            Text('确认订单',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: context.lgTextPrimary)),
            SizedBox(height: 12),
            ...kitchen.cartDishes.map((d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Text(d.emoji, style: const TextStyle(fontSize: 20)),
                      SizedBox(width: 10),
                      Expanded(
                          child: Text(d.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600))),
                      Text('x${kitchen.cart[d.id] ?? 0}',
                          style:
                              TextStyle(color: context.lgTextMuted)),
                      SizedBox(width: 12),
                      Text('¥${d.price * (kitchen.cart[d.id] ?? 0)}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                )),
            Divider(height: 24, color: context.lgSeparator),
            TextField(
              controller: _noteCtrl,
              maxLength: 60,
              decoration: InputDecoration(
                hintText: '给主厨留言，比如：周五晚上想吃～',
                hintStyle:
                    TextStyle(color: context.lgTextMuted, fontSize: 13),
                filled: true,
                fillColor: context.lgPaper,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: context.lgSeparator)),
                counterText: '',
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: LovePrimaryButton(
                text: '下单 · 等主厨开火',
                onPressed: () async {
                  final err = await kitchen.placeOrder(_noteCtrl.text.trim());
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  if (err == null) HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(err ?? '下单成功！等 TA 开火啦 🔥'),
                    behavior: SnackBarBehavior.floating,
                  ));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= 我的厨房 =================

class _MyKitchenTab extends StatelessWidget {
  final KitchenProvider kitchen;
  const _MyKitchenTab({required this.kitchen});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        kitchen.mine.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('👨‍🍳', style: TextStyle(fontSize: 52)),
                    const SizedBox(height: 12),
                    Text('你的菜单还是空的',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.lgTextPrimary)),
                    const SizedBox(height: 6),
                    Text('把会做的菜挂上来，等 TA 来点',
                        style: TextStyle(
                            fontSize: 12, color: context.lgTextMuted)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                itemCount: kitchen.mine.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final dish = kitchen.mine[i];
                  return _MyDishCard(
                    dish: dish,
                    onEdit: () => _showDishSheet(context, dish: dish),
                    onDelete: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                          title: const Text('下架菜品'),
                          content: Text('把「${dish.name}」从菜单上撤下来吗？'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(dCtx, false),
                                child: const Text('再想想')),
                            TextButton(
                                onPressed: () => Navigator.pop(dCtx, true),
                                child: const Text('下架',
                                    style:
                                        TextStyle(color: LoveGirlTheme.red))),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        await kitchen.deleteDish(dish.id);
                      }
                    },
                  );
                },
              ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: LovePrimaryButton(
            text: '+ 添加一道拿手菜',
            onPressed: () => _showDishSheet(context),
          ),
        ),
      ],
    );
  }

  void _showDishSheet(BuildContext context, {KitchenDish? dish}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DishEditSheet(existing: dish),
    );
  }
}

class _MyDishCard extends StatelessWidget {
  final KitchenDish dish;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MyDishCard({
    required this.dish,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.lgPaper,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(14),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 56,
              height: 56,
              child: dish.photoUrl != null
                  ? Image.network(
                      kitchenPhotoUrl(dish.photoUrl!, AppConstants.baseUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _emojiBox(context),
                    )
                  : _emojiBox(context),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dish.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.lgTextPrimary)),
                SizedBox(height: 4),
                Text(
                  '${dish.category} · ${dish.price > 0 ? '¥${dish.price}' : '心意价'}'
                  '${dish.description == null || dish.description!.isEmpty ? '' : ' · ${dish.description}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12, color: context.lgTextMuted),
                ),
              ],
            ),
          ),
          IconButton(
              onPressed: onEdit,
              icon: Icon(Icons.edit_outlined,
                  size: 20, color: context.lgTextSecondary)),
          IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 20, color: LoveGirlTheme.red)),
        ],
      ),
    );
  }

  Widget _emojiBox(context) => Container(
        color: context.lgSecondarySoft,
        alignment: Alignment.center,
        child: Text(dish.emoji, style: const TextStyle(fontSize: 25)),
      );
}

// ================= 菜品编辑 =================

class _DishEditSheet extends StatefulWidget {
  final KitchenDish? existing;
  const _DishEditSheet({this.existing});

  @override
  State<_DishEditSheet> createState() => _DishEditSheetState();
}

class _DishEditSheetState extends State<_DishEditSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _emoji =
      TextEditingController(text: widget.existing?.emoji ?? '🍳');
  late final TextEditingController _price = TextEditingController(
      text: widget.existing != null && widget.existing!.price > 0
          ? '${widget.existing!.price}'
          : '');
  late final TextEditingController _desc =
      TextEditingController(text: widget.existing?.description ?? '');
  late String _category = widget.existing?.category ?? '家常菜';
  late String? _photoUrl = widget.existing?.photoUrl;
  bool _saving = false;
  bool _uploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _name.dispose();
    _emoji.dispose();
    _price.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final kitchen = context.read<KitchenProvider>();
    final xFile = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1200, imageQuality: 82);
    if (xFile == null) return;
    setState(() => _uploading = true);
    final (url, err) = await kitchen.uploadPhoto(xFile.path);
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (url != null) _photoUrl = url;
    });
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.lgBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: context.lgSeparator,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              SizedBox(height: 14),
              Text(widget.existing == null ? '添加拿手菜' : '编辑菜品',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: context.lgTextPrimary)),
              SizedBox(height: 14),
              Row(
                children: [
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: context.lgPrimarySoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: _uploading
                          ? const Center(
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)))
                          : _photoUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                      kitchenPhotoUrl(
                                          _photoUrl!, AppConstants.baseUrl),
                                      fit: BoxFit.cover))
                              : Icon(Icons.add_a_photo_rounded,
                                  color: context.lgInk),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _name,
                      decoration: InputDecoration(
                          labelText: '菜名（必填）',
                          filled: true,
                          fillColor: context.lgPaper),
                    ),
                  ),
                  SizedBox(width: 12),
                  SizedBox(
                    width: 64,
                    child: TextField(
                      controller: _emoji,
                      textAlign: TextAlign.center,
                      maxLength: 2,
                      decoration: InputDecoration(
                          counterText: '', filled: true, fillColor: context.lgPaper),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['硬菜', ..._presetCategories.skip(1), '拿手菜']
                    .map((c) => ChoiceChip(
                          label: Text(c),
                          selected: _category == c,
                          selectedColor: context.lgPrimarySoft,
                          labelStyle: TextStyle(
                              color: _category == c
                                  ? context.lgInk
                                  : context.lgTextSecondary,
                              fontWeight: FontWeight.w600),
                          onSelected: (_) => setState(() => _category = c),
                        ))
                    .toList(),
              ),
              SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: '趣味价（¥，可不填）',
                          filled: true,
                          fillColor: context.lgPaper),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14),
              TextField(
                controller: _desc,
                maxLength: 100,
                decoration: InputDecoration(
                    labelText: '一句推荐语（可不填）',
                    hintText: '比如：入口即化，吃过都说好',
                    filled: true,
                    fillColor: context.lgPaper,
                    counterText: ''),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
              child: LovePrimaryButton(
                text: widget.existing == null ? '挂上菜单' : '保存修改',
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('先给菜起个名字吧'), behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _saving = true);
    final kitchen = context.read<KitchenProvider>();
    final data = {
      'name': name,
      'category': _category,
      'emoji': _emoji.text.trim().isEmpty ? '🍳' : _emoji.text.trim(),
      'price': int.tryParse(_price.text.trim()) ?? 0,
      'description': _desc.text.trim(),
      if (_photoUrl != null) 'photo_url': _photoUrl,
    };
    final err = widget.existing == null
        ? await kitchen.createDish(data)
        : await kitchen.updateDish(widget.existing!.id, data);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? (widget.existing == null ? '已挂上菜单 ✅' : '已保存 ✅')),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ================= 开饭记录（投喂小票） =================

class _RecordsTab extends StatelessWidget {
  final KitchenProvider kitchen;
  const _RecordsTab({required this.kitchen});

  @override
  Widget build(BuildContext context) {
    final done = [...kitchen.incoming, ...kitchen.outgoing]
        .where((o) => o.status == 'done')
        .toList()
      ..sort((a, b) => (b.doneAt ?? '').compareTo(a.doneAt ?? ''));
    if (done.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🧾', style: TextStyle(fontSize: 52)),
            SizedBox(height: 12),
            Text('还没有开火记录',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.lgTextPrimary)),
            SizedBox(height: 6),
            Text('完成第一单后，这里会留下投喂小票',
                style: TextStyle(fontSize: 12, color: context.lgTextMuted)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: done.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _ReceiptCard(order: done[i]),
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final KitchenOrder order;
  const _ReceiptCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final dateStr = (order.doneAt ?? order.createdAt ?? '').split('.').first;
    return LoveTicketCard(
      padding: const EdgeInsets.all(14),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_fire_department_rounded,
                      size: 18, color: context.lgInk),
                  SizedBox(width: 6),
                  Text('投喂小票',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: context.lgTextPrimary)),
                  Spacer(),
                  Text('#${order.id}',
                      style: TextStyle(
                          fontSize: 12, color: context.lgTextMuted)),
                ],
              ),
              SizedBox(height: 8),
              LoveTicketDivider(),
              SizedBox(height: 8),
              ...order.items.map((it) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Text(it.emoji, style: const TextStyle(fontSize: 15)),
                        SizedBox(width: 8),
                        Expanded(
                            child: Text('${it.name} x${it.quantity}',
                                style: const TextStyle(fontSize: 13))),
                        Text('¥${it.price * it.quantity}',
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  )),
              SizedBox(height: 6),
              LoveTicketDivider(),
              SizedBox(height: 8),
              Row(
                children: [
                  Text(dateStr,
                      style: TextStyle(
                          fontSize: 12, color: context.lgTextMuted)),
                  Spacer(),
                  Text('合计 ¥${order.totalPrice}',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: context.lgTextPrimary)),
                ],
              ),
              if (order.photoUrl != null) ...[
                SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: Image.network(
                      kitchenPhotoUrl(order.photoUrl!, AppConstants.baseUrl),
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
              SizedBox(height: 8),
              LoveBarcode(),
            ],
          ),
          Positioned(
            right: 4,
            top: 26,
            child: Transform.rotate(
              angle: -0.35,
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: context.lgInk, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  color: context.lgPrimarySoft.withAlpha(200),
                ),
                child: Text('已开火 ♥',
                    style: TextStyle(
                        color: context.lgInk,
                        fontWeight: FontWeight.w900,
                        fontSize: 13)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= 订单管理页 =================

class KitchenOrdersScreen extends StatelessWidget {
  const KitchenOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kitchen = context.watch<KitchenProvider>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: context.lgBg,
        appBar: AppBar(
          backgroundColor: context.lgBg,
          foregroundColor: context.lgTextPrimary,
          elevation: 0,
          title: const Text('订单',
              style: TextStyle(fontWeight: FontWeight.w900)),
          bottom: TabBar(
            labelColor: context.lgInk,
            unselectedLabelColor: context.lgTextMuted,
            indicatorColor: context.lgInk,
            tabs: [Tab(text: '收到的订单'), Tab(text: '我下的订单')],
          ),
        ),
        body: TabBarView(
          children: [
            _OrdersList(orders: kitchen.incoming, isIncoming: true),
            _OrdersList(orders: kitchen.outgoing, isIncoming: false),
          ],
        ),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final List<KitchenOrder> orders;
  final bool isIncoming;

  const _OrdersList({required this.orders, required this.isIncoming});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isIncoming ? Icons.inbox_rounded : Icons.send_rounded,
                size: 48, color: context.lgTextMuted),
            SizedBox(height: 10),
            Text(isIncoming ? '还没有收到订单' : '还没点过菜',
                style: TextStyle(color: context.lgTextMuted)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) =>
          _OrderCard(order: orders[i], isIncoming: isIncoming),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final KitchenOrder order;
  final bool isIncoming;

  const _OrderCard({required this.order, required this.isIncoming});

  String get _statusLabel {
    switch (order.status) {
      case 'placed':
        return '待接单';
      case 'accepted':
        return '烹饪中';
      case 'done':
        return '已完成';
      case 'cancelled':
        return '已取消';
      default:
        return order.status;
    }
  }

  Color _statusColor(BuildContext context) {
    switch (order.status) {
      case 'placed':
        return LoveGirlTheme.orange;
      case 'accepted':
        return context.lgInk;
      case 'done':
        return LoveGirlTheme.secondary;
      default:
        return context.lgTextMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final kitchen = context.read<KitchenProvider>();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.lgPaper,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(14),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#${order.id}',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: context.lgTextPrimary)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  isIncoming ? 'TA 想吃：' : '你点的：',
                  style: TextStyle(
                      fontSize: 12, color: context.lgTextMuted),
                ),
              ),
              LovePill(
                text: _statusLabel,
                color: _statusColor(context),
                background: _statusColor(context).withAlpha(20),
              ),
            ],
          ),
          SizedBox(height: 8),
          ...order.items.map((it) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text(it.emoji, style: const TextStyle(fontSize: 15)),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text('${it.name} x${it.quantity}',
                            style: const TextStyle(fontSize: 13))),
                  ],
                ),
              )),
          if (order.note != null && order.note!.isNotEmpty) ...[
            SizedBox(height: 6),
            Text('留言：${order.note}',
                style: TextStyle(
                    fontSize: 12, color: context.lgTextSecondary)),
          ],
          SizedBox(height: 10),
          Row(
            children: [
              Text('合计 ¥${order.totalPrice}',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: context.lgTextPrimary)),
              Spacer(),
              if (isIncoming && order.status == 'placed')
                _AcceptWithUndo(orderId: order.id),
              if (isIncoming && order.status == 'accepted')
                GestureDetector(
                  onTap: () => _showFulfillSheet(context, order.id),
                  child: LovePill(
                    text: '完成并拍照',
                    icon: Icons.camera_alt_rounded,
                    color: LoveGirlTheme.secondary,
                    background: context.lgSecondarySoft,
                  ),
                ),
              if (!isIncoming && order.isActive)
                GestureDetector(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                        title: const Text('取消订单'),
                        content: const Text('确定不想吃这单了吗？'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(dCtx, false),
                              child: const Text('再想想')),
                          TextButton(
                              onPressed: () => Navigator.pop(dCtx, true),
                              child: const Text('取消订单',
                                  style:
                                      TextStyle(color: LoveGirlTheme.red))),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      final err = await kitchen
                          .updateOrderStatus(order.id, 'cancelled');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(err ?? '订单已取消'),
                            behavior: SnackBarBehavior.floating));
                      }
                    }
                  },
                  child: LovePill(
                    text: '取消订单',
                    icon: Icons.close_rounded,
                    color: context.lgTextMuted,
                    background: context.lgSeparator,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFulfillSheet(BuildContext context, int orderId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FulfillSheet(orderId: orderId),
    );
  }
}

// ================= 完成订单（拍成品照） =================

class _FulfillSheet extends StatefulWidget {
  final int orderId;
  const _FulfillSheet({required this.orderId});

  @override
  State<_FulfillSheet> createState() => _FulfillSheetState();
}

class _FulfillSheetState extends State<_FulfillSheet> {
  XFile? _photo;
  bool _working = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pick(ImageSource source) async {
    final xFile = await _picker.pickImage(
        source: source, maxWidth: 1600, imageQuality: 85);
    if (xFile == null) return;
    setState(() => _photo = xFile);
  }

  Future<void> _submit() async {
    if (_photo == null) return;
    setState(() => _working = true);
    final kitchen = context.read<KitchenProvider>();
    final (url, uploadErr) = await kitchen.uploadPhoto(_photo!.path);
    if (!mounted) return;
    if (uploadErr != null || url == null) {
      setState(() => _working = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(uploadErr ?? '上传失败，再试一次'),
          behavior: SnackBarBehavior.floating));
      return;
    }
    final err = await kitchen
        .updateOrderStatus(widget.orderId, 'done', extra: {'photo_url': url});
    if (!mounted) return;
    setState(() => _working = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? '这单完成！+5 爱心豆 🫘'),
        behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    // 订单 id 由打开方传入（通过 provider 暂存，见 _OrderCard 调用处）
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.lgBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: context.lgSeparator,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Text('菜做好了？拍张成品照',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: context.lgTextPrimary)),
            const SizedBox(height: 4),
            Text('照片会成为这单的投喂小票和回忆素材',
                style: TextStyle(fontSize: 12, color: context.lgTextMuted)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _working ? null : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('拍照'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _working ? null : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_rounded),
                    label: const Text('相册选'),
                  ),
                ),
              ],
            ),
            if (_photo != null) ...[
              SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  File(_photo!.path),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: LovePrimaryButton(
                text: _working ? '上传中…' : '完成这单',
                onPressed: (_working || _photo == null) ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 接单（可撤销）：接单成功后 3 秒内出现撤销钮，跟手拖动松手判定
class _AcceptWithUndo extends StatefulWidget {
  final int orderId;
  const _AcceptWithUndo({required this.orderId});

  @override
  State<_AcceptWithUndo> createState() => _AcceptWithUndoState();
}

class _AcceptWithUndoState extends State<_AcceptWithUndo> {
  bool _accepted = false;
  Timer? _undoTimer;
  double _dragOffset = -80;

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  Future<void> _accept() async {
    final kitchen = context.read<KitchenProvider>();
    final err = await kitchen.updateOrderStatus(widget.orderId, 'accepted');
    if (!mounted) return;
    if (err == null) {
      HapticFeedback.mediumImpact();
      setState(() => _accepted = true);
      _undoTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _dragOffset = -80);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('已接单，3 秒内可撤销'),
          behavior: SnackBarBehavior.floating));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final kitchen = context.read<KitchenProvider>();
    if (!_accepted) {
      return GestureDetector(
        onTap: _accept,
        child: LovePill(
          text: '接单',
          icon: Icons.check_rounded,
          color: context.lgInk,
          background: context.lgPrimarySoft,
        ),
      );
    }
    return GestureDetector(
      onHorizontalDragUpdate: (d) => setState(
          () => _dragOffset = (_dragOffset + d.delta.dx).clamp(-80.0, 0.0)),
      onHorizontalDragEnd: (d) async {
        final undo = _dragOffset > -40;
        setState(() => _dragOffset = -80);
        _undoTimer?.cancel();
        if (undo) {
          final err =
              await kitchen.updateOrderStatus(widget.orderId, 'placed');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(err ?? '已撤销接单'),
                behavior: SnackBarBehavior.floating));
          }
        }
      },
      child: Transform.translate(
        offset: Offset(_dragOffset + 80, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: context.lgSecondarySoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.undo_rounded, size: 14, color: LoveGirlTheme.secondary),
              const SizedBox(width: 4),
              Text('撤销',
                  style: TextStyle(
                      color: LoveGirlTheme.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}