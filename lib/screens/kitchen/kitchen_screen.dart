import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/kitchen_provider.dart';
import '../../utils/constants.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/lovegirl_ui.dart';
import '../couple/couple_binding_screen.dart';
import '../../widgets/illus_image.dart';
import '../../widgets/rebuild_controls.dart';
import '../cooking/cooking_log_screen.dart';
import 'kitchen_menu_grid.dart';
import 'kitchen_meal_fields.dart';
import 'kitchen_meal_editor.dart';
import 'kitchen_photo.dart';

/// 情侣厨房：照片菜单 / 这一餐 / 开饭记录
class KitchenScreen extends StatelessWidget {
  final int initialTab;
  const KitchenScreen({super.key, this.initialTab = 0})
      : assert(initialTab >= 0 && initialTab < 3);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: context.read<KitchenProvider>(),
      child: _KitchenView(initialTab: initialTab),
    );
  }
}

class _KitchenView extends StatefulWidget {
  final int initialTab;
  const _KitchenView({this.initialTab = 0});

  @override
  State<_KitchenView> createState() => _KitchenViewState();
}

class _KitchenViewState extends State<_KitchenView>
    with SingleTickerProviderStateMixin {
  late final TabController _tab =
      TabController(length: 3, initialIndex: widget.initialTab, vsync: this);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<KitchenProvider>().refreshAll();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.lgBg,
        body: RebuildPageBackground(
            child: SafeArea(
                child: Consumer<KitchenProvider>(
          builder: (context, kitchen, _) => Column(children: [
            _KitchenHeader(
                title: '情侣厨房',
                subtitle: '今晚想吃什么？',
                onManage: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const KitchenMenuManagementScreen()));
                  if (mounted) await kitchen.loadMenu(silent: true);
                }),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: RebuildGlass(
                  radius: 26,
                  child: TabBar(
                    controller: _tab,
                    dividerColor: Colors.transparent,
                    labelColor: context.lgInk,
                    unselectedLabelColor: context.lgTextMuted,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                    unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w400, fontSize: 14),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.all(3),
                    indicator: BoxDecoration(
                        color: context.lgPaper.withAlpha(190),
                        borderRadius: BorderRadius.circular(24)),
                    tabs: const [
                      Tab(text: '菜单'),
                      Tab(text: '这一餐'),
                      Tab(text: '开饭记录')
                    ],
                  ),
                )),
            if (kitchen.error != null)
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    Expanded(
                        child: Text(kitchen.error!,
                            style: TextStyle(
                                fontSize: 12, color: context.lgTextSecondary))),
                    TextButton(
                        onPressed: () => kitchen.refreshAll(),
                        child: const Text('重试')),
                  ])),
            Expanded(
                child: TabBarView(controller: _tab, children: [
              _MenuTab(kitchen: kitchen, onOrdered: () => _tab.animateTo(1)),
              _CurrentMealTab(
                  kitchen: kitchen, onMenu: () => _tab.animateTo(0)),
              _RecordsTab(kitchen: kitchen),
            ])),
          ]),
        ))),
      );
}

class _KitchenHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onManage;
  const _KitchenHeader(
      {required this.title, required this.subtitle, this.onManage});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(children: [
          RebuildGlassButton(
              label: '返回',
              icon: Icons.arrow_back_ios_new_rounded,
              onPressed: () => Navigator.maybePop(context)),
          const SizedBox(width: 8),
          Expanded(
              child: Column(children: [
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 24, height: 1.1, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, height: 1.15, color: context.lgTextMuted)),
          ])),
          const SizedBox(width: 8),
          if (onManage != null)
            RebuildGlassButton(
                label: '管理我的菜单', icon: Icons.edit_outlined, onPressed: onManage)
          else
            const SizedBox(width: 48),
        ]),
      );
}

/// Own menu remains usable before binding a partner.
class KitchenMenuManagementScreen extends StatefulWidget {
  const KitchenMenuManagementScreen({super.key});
  @override
  State<KitchenMenuManagementScreen> createState() =>
      _KitchenMenuManagementScreenState();
}

class _KitchenMenuManagementScreenState
    extends State<KitchenMenuManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<KitchenProvider>().loadMenu();
    });
  }

  @override
  Widget build(BuildContext context) {
    final kitchen = context.watch<KitchenProvider>();
    return Scaffold(
      backgroundColor: context.lgBg,
      body: RebuildPageBackground(
          child: SafeArea(
              child: Column(children: [
        const _KitchenHeader(title: '我的菜单', subtitle: '留下自己会做的拿手菜'),
        if (kitchen.menuError != null)
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(kitchen.menuError!,
                  style: TextStyle(color: context.lgTextSecondary))),
        Expanded(
            child: kitchen.loading && !kitchen.menuLoaded
                ? const Center(child: CircularProgressIndicator())
                : _MyKitchenTab(kitchen: kitchen)),
      ]))),
    );
  }
}

class _UnboundView extends StatelessWidget {
  final KitchenProvider kitchen;
  const _UnboundView({required this.kitchen});
  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: RebuildGlass(
              radius: 22,
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(children: [
                const Expanded(
                    child: Text('可以先整理自己的菜单\n绑定后一起商量每一餐',
                        style: TextStyle(fontSize: 12))),
                TextButton(
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const CoupleBindingScreen()));
                      if (context.mounted) await kitchen.refreshAll();
                    },
                    child: const Text('去绑定')),
              ]),
            )),
        Expanded(child: _MyKitchenTab(kitchen: kitchen)),
      ]);
}

class _CurrentMealTab extends StatelessWidget {
  final KitchenProvider kitchen;
  final VoidCallback onMenu;
  const _CurrentMealTab({required this.kitchen, required this.onMenu});
  @override
  Widget build(BuildContext context) {
    if (!kitchen.ordersLoaded && kitchen.ordersError == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final orders = [...kitchen.incoming, ...kitchen.outgoing]
        .where((o) => o.isActive)
        .toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    if (orders.isEmpty) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restaurant_outlined,
                      size: 40, color: context.lgTextMuted),
                  const SizedBox(height: 12),
                  Text(kitchen.ordersError ?? '这一餐还没安排',
                      textAlign: TextAlign.center),
                  TextButton(
                      onPressed: kitchen.ordersError == null
                          ? onMenu
                          : () => kitchen.loadOrders(),
                      child: Text(
                          kitchen.ordersError == null ? '从菜单选几道菜' : '重新加载餐次')),
                ],
              )));
    }
    return RefreshIndicator(
        onRefresh: () => kitchen.loadOrders(),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _OrderCard(
              order: orders[i],
              isIncoming: kitchen.incoming.any((o) => o.id == orders[i].id)),
        ));
  }
}

const List<String> _presetCategories = [
  '硬菜',
  '家常菜',
  '汤羹',
  '主食',
  '甜品',
  '夜宵',
  '饮品',
];

class _MenuTab extends StatelessWidget {
  final KitchenProvider kitchen;
  final VoidCallback onOrdered;
  const _MenuTab({required this.kitchen, required this.onOrdered});
  @override
  Widget build(BuildContext context) {
    if (!kitchen.menuLoaded && kitchen.menuError == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (kitchen.menuError != null && !kitchen.menuLoaded) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(kitchen.menuError!, textAlign: TextAlign.center),
          TextButton(
              onPressed: () => kitchen.loadMenu(), child: const Text('重新加载菜单')),
        ]),
      ));
    }
    if (!kitchen.bound) return _UnboundView(kitchen: kitchen);
    return KitchenMenuGrid(
        kitchen: kitchen,
        onOpenCart: () async {
          final saved = await showModalBottomSheet<bool>(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => const _CartSheet());
          if (context.mounted && saved == true) onOrdered();
        });
  }
}

// ================= 购物车下单 =================

/// v4.0 弹层玻璃化统一口径外壳（radiusXl 28 / 白 72% / blur 24），
/// 深色=cardDark 72% 同成立；键盘 inset 由调用方 Padding 负责。
class _KitchenGlassSheet extends StatelessWidget {
  final Widget child;

  const _KitchenGlassSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(top: Radius.circular(LoveGirlTheme.radiusXl));
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            // v4.1：72%→58%，磨砂透底感更接近参考图
            color: context.lgPaper.withValues(alpha: 0.58),
            borderRadius: radius,
            border: Border(top: BorderSide(color: context.lgCardBorder)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: child,
        ),
      ),
    );
  }
}

class _CartSheet extends StatefulWidget {
  const _CartSheet();

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  final TextEditingController _noteCtrl = TextEditingController();
  String? _mealDate;
  String? _mealSlot;

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
      // v4.0 弹层玻璃化统一口径（radiusXl 28 / 白 72% / blur 24）
      child: SingleChildScrollView(child: _KitchenGlassSheet(
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
            Text('确认这一餐',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: context.lgTextPrimary)),
            SizedBox(height: 12),
            Text(kitchen.cookMyself ? '我来掌勺' : '${kitchen.partnerName ?? 'TA'}来掌勺'),
            const SizedBox(height: 8),
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
                      if (d.price > 0) Text('参考 ¥${d.price * (kitchen.cart[d.id] ?? 0)}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                )),
            Divider(height: 24, color: context.lgSeparator),
            KitchenMealFields(date: _mealDate, slot: _mealSlot,
              enabled: !kitchen.placingOrder,
              onDate: (value) => setState(() => _mealDate = value),
              onSlot: (value) => setState(() => _mealSlot = value)),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              maxLength: 300,
              enabled: !kitchen.placingOrder,
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
                text: kitchen.placingOrder ? '提交中…' : '提交这一餐',
                onPressed: kitchen.placingOrder || kitchen.cart.isEmpty ? null : () async {
                  final err = await kitchen.placeOrder(_noteCtrl.text.trim(), mealDate: _mealDate, mealSlot: _mealSlot);
                  if (!context.mounted) return;
                  if (err == null) Navigator.of(context).pop(true);
                  if (err == null) HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(err ?? '这一餐已安排，等待主厨确认'),
                    behavior: SnackBarBehavior.floating,
                  ));
                },
              ),
            ),
          ],
        ),
      )),
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
                    IllusImg('ui_kitchen', height: 120),
                    const SizedBox(height: 12),
                    Text(kitchen.menuError == null ? '你的菜单还是空的' : '菜单暂未加载',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.lgTextPrimary)),
                    const SizedBox(height: 6),
                    Text(kitchen.menuError == null ? '把会做的菜挂上来，等 TA 来点' : '可以稍后重试，或先添加一道拿手菜',
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
                          // v4.0 弹层大圆角 + 1px 细线
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(LoveGirlTheme.radiusXl),
                              side: BorderSide(color: dCtx.lgCardBorder)),
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
                        final error = await kitchen.deleteDish(dish.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(error ?? '已从菜单下架'),
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
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
    // v4.0 白卡=大圆角+1px 细线（LovePaper），阴影交给描边
    return LovePaper(
      padding: const EdgeInsets.all(12),
      radius: LoveGirlTheme.radiusLg,
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
  late final TextEditingController _ingredients = TextEditingController(text: widget.existing?.ingredients ?? '');
  late final TextEditingController _recipe = TextEditingController(text: widget.existing?.recipe ?? '');
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
    _ingredients.dispose();
    _recipe.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_saving || _uploading) return;
    final kitchen = context.read<KitchenProvider>();
    final xFile = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1200, imageQuality: 82);
    if (!mounted || xFile == null) return;
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
      // v4.0 弹层玻璃化统一口径（radiusXl 28 / 白 72% / blur 24）
      child: _KitchenGlassSheet(
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
                          // v4.0 选中=黑胶囊白字（参考图③）
                          selectedColor: context.lgInk,
                          labelStyle: TextStyle(
                              color: _category == c
                                  ? Colors.white
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
              const SizedBox(height: 12),
              TextField(controller: _ingredients, minLines: 2, maxLines: 4, maxLength: 2000,
                decoration: const InputDecoration(labelText: '食材（可选）', counterText: '')),
              const SizedBox(height: 12),
              TextField(controller: _recipe, minLines: 2, maxLines: 4, maxLength: 3000,
                decoration: const InputDecoration(labelText: '做法（可选）', counterText: '')),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
              child: LovePrimaryButton(
                text: widget.existing == null ? '挂上菜单' : '保存修改',
                  onPressed: _saving || _uploading ? null : _save,
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
      'ingredients': _ingredients.text.trim(),
      'recipe': _recipe.text.trim(),
      if (_photoUrl != null) 'photo_url': _photoUrl,
    };
    final err = widget.existing == null
        ? await kitchen.createDish(data)
        : await kitchen.updateDish(widget.existing!.id, data);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err == null) Navigator.of(context).pop();
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
    if (!kitchen.ordersLoaded) {
      if (kitchen.ordersError == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(kitchen.ordersError!, textAlign: TextAlign.center),
                  TextButton(
                      onPressed: () => kitchen.loadOrders(),
                      child: const Text('重新加载记录')),
                ],
              )));
    }
    final done = [...kitchen.incoming, ...kitchen.outgoing]
        .where((o) => o.status == 'done')
        .toList()
      ..sort((a, b) => (b.doneAt ?? '').compareTo(a.doneAt ?? ''));
    if (done.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IllusImg('ui_kitchen', height: 120),
            SizedBox(height: 12),
            Text('还没有开饭记录',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.lgTextPrimary)),
            SizedBox(height: 6),
            Text('完成一餐后，照片和留言会留在这里',
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
    final rawDate =
        (order.doneAt ?? order.createdAt ?? '').replaceAll('T', ' ');
    final date = rawDate.length > 16 ? rawDate.substring(0, 16) : rawDate;
    final quantity =
        order.items.fold<int>(0, (sum, item) => sum + item.quantity);
    return LoveTicketCard(
      padding: const EdgeInsets.all(16),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.restaurant_outlined, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                  child: Text('餐桌记录',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600))),
              Text('#${order.id}',
                  style: TextStyle(fontSize: 12, color: context.lgTextMuted)),
            ]),
            const SizedBox(height: 12),
            LoveTicketDivider(
                axis: Axis.horizontal,
                length: double.infinity,
                color: context.lgSeparator),
            const SizedBox(height: 12),
            ...order.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(
                      child: Text(item.name,
                          style: const TextStyle(fontSize: 14))),
                  const SizedBox(width: 12),
                  Text('×${item.quantity}',
                      style: TextStyle(
                          fontSize: 13, color: context.lgTextSecondary)),
                ]))),
            if (order.note?.isNotEmpty == true)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(order.note!,
                      style: TextStyle(
                          fontSize: 12, color: context.lgTextSecondary))),
            if (order.photoUrl?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                      aspectRatio: 1.8,
                      child: KitchenPhoto(path: order.photoUrl, cacheWidth: 800))),
            ],
            const SizedBox(height: 12),
            LoveTicketDivider(
                axis: Axis.horizontal,
                length: double.infinity,
                color: context.lgSeparator),
            const SizedBox(height: 10),
            Wrap(spacing: 12, runSpacing: 6, children: [
              if (date.isNotEmpty)
                Text(date,
                    style: TextStyle(fontSize: 12, color: context.lgTextMuted)),
              Text('共 $quantity 份',
                  style:
                      TextStyle(fontSize: 12, color: context.lgTextSecondary)),
              const Text('已开饭',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            if (order.totalPrice > 0)
              Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('菜单参考价 ¥${order.totalPrice}',
                      style:
                          TextStyle(fontSize: 11, color: context.lgTextMuted))),
            TextButton(onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => KitchenMealScreen(orderId: order.id)));
              if (context.mounted) await context.read<KitchenProvider>().loadOrders(silent: true);
            }, child: const Text('查看这一餐')),
          ]),
    );
  }
}

/// A meal can be opened from a notification, its receipt, or the food journal.
class KitchenMealScreen extends StatefulWidget {
  final int orderId;
  const KitchenMealScreen({super.key, required this.orderId});
  @override
  State<KitchenMealScreen> createState() => _KitchenMealScreenState();
}

class _KitchenMealScreenState extends State<KitchenMealScreen> {
  KitchenOrder? _order;
  String? _error;
  bool _loading = true;
  int _request = 0;
  int? _actor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final actor = context.watch<KitchenProvider>().accountId;
    if (_request == 0 || _actor != actor) {
      _actor = actor; _request++; _order = null; _error = null; _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
    }
  }

  Future<void> _load() async {
    final kitchen = context.read<KitchenProvider>();
    final request = ++_request;
    setState(() { _loading = true; _error = null; });
    final (order, error) = await kitchen.getOrder(widget.orderId);
    if (!mounted || request != _request) return;
    if (order?.isActive == true && (!kitchen.menuLoaded || kitchen.menuError != null)) {
      await kitchen.loadMenu(silent: true);
    }
    if (!mounted || request != _request) return;
    setState(() { _loading = false; _error = error; _order = order; });
  }

  @override
  Widget build(BuildContext context) {
    final kitchen = context.watch<KitchenProvider>();
    final order = _order;
    return Scaffold(backgroundColor: context.lgBg, body: RebuildPageBackground(child: SafeArea(child: Column(children: [
      const _KitchenHeader(title: '这一餐', subtitle: '菜品与餐桌回忆'),
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : order == null
        ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error ?? '餐次不可见或已删除', textAlign: TextAlign.center),
          TextButton(onPressed: _load, child: const Text('重试')),
        ])))
        : RefreshIndicator(onRefresh: _load, child: ListView(
          physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(12), children: [
            if (order.photoUrl?.isNotEmpty == true) ...[
              ClipRRect(borderRadius: BorderRadius.circular(20), child: AspectRatio(aspectRatio: 1.6,
                child: KitchenPhoto(path: order.photoUrl, cacheWidth: 800))), const SizedBox(height: 12),
            ],
            _OrderCard(order: order, isIncoming: order.cookId == kitchen.accountId, onChanged: _load),
            for (final item in order.items)
              if (item.ingredients?.isNotEmpty == true || item.recipe?.isNotEmpty == true)
                Padding(padding: const EdgeInsets.only(top: 12), child: LovePaper(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    if (item.ingredients?.isNotEmpty == true) ...[const SizedBox(height: 8), const Text('食材'), Text(item.ingredients!)],
                    if (item.recipe?.isNotEmpty == true) ...[const SizedBox(height: 8), const Text('做法'), Text(item.recipe!)],
                  ],
                ))),
            if (order.cookingLogId != null) Padding(padding: const EdgeInsets.only(top: 14), child: FilledButton.icon(
              style: rebuildFilledStyle(context), icon: const Icon(Icons.auto_stories_outlined), label: const Text('查看餐桌回忆'),
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CookingLogScreen(logId: order.cookingLogId)));
                if (mounted) await _load();
              },
            )),
          ],
        )),
      ),
    ]))),
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
  final VoidCallback? onChanged;

  const _OrderCard({required this.order, required this.isIncoming, this.onChanged});

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
    final kitchen = context.watch<KitchenProvider>();
    final canAdjust = canAdjustKitchenMeal(kitchen, order);
    final canCook = isIncoming && (!kitchen.menuLoaded || canAdjust);
    // v4.0 白卡=大圆角+1px 细线（LovePaper），阴影交给描边
    return LovePaper(
      padding: const EdgeInsets.all(14),
      radius: LoveGirlTheme.radiusLg,
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
                  isIncoming ? '我掌勺' : 'TA掌勺',
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
          if (kitchenMealPlanLabel(order.mealDate, order.mealSlot).isNotEmpty)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(kitchenMealPlanLabel(order.mealDate, order.mealSlot))),
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(order.totalPrice > 0 ? '菜单参考价 ¥${order.totalPrice}' : '共 ${order.items.fold<int>(0, (sum, item) => sum + item.quantity)} 份',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: context.lgTextPrimary)),
              if (canCook && order.status == 'placed')
                _MealStatusButton(order: order, status: 'accepted', text: '接下这一餐', onChanged: onChanged),
              if (canCook && order.status == 'accepted')
                Wrap(children: [
                  _MealStatusButton(order: order, status: 'placed', text: '撤销接单', onChanged: onChanged),
                  TextButton(
                    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    onPressed: kitchen.isOrderBusy(order.id) ? null : () => _showFulfillSheet(context),
                    child: const Text('开饭了'),
                  ),
                ]),
              if (canAdjust)
                TextButton(onPressed: kitchen.isOrderBusy(order.id) ? null : () async {
                  final saved = await showKitchenMealEditor(context, order.id);
                  if (context.mounted && saved == true) onChanged?.call();
                }, child: const Text('调整餐次')),
              if (kitchen.accountId == order.ordererId && order.isActive)
                GestureDetector(
                  onTap: kitchen.isOrderBusy(order.id) ? null : () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        // v4.0 弹层大圆角 + 1px 细线
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(LoveGirlTheme.radiusXl),
                            side: BorderSide(color: dCtx.lgCardBorder)),
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
                          .updateOrderStatus(order.id, 'cancelled', extra: order.expectedState);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(err ?? '订单已取消'),
                            behavior: SnackBarBehavior.floating));
                        if (err == null) onChanged?.call();
                      }
                    }
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                    child: Center(widthFactor: 1, child: LovePill(
                    text: '取消订单',
                    icon: Icons.close_rounded,
                    color: context.lgTextMuted,
                    background: context.lgSeparator,
                  ))),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showFulfillSheet(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FulfillSheet(order: order),
    );
    if (context.mounted && saved == true) onChanged?.call();
  }
}

// ================= 完成订单（拍成品照） =================

class _FulfillSheet extends StatefulWidget {
  final KitchenOrder order;
  const _FulfillSheet({required this.order});

  @override
  State<_FulfillSheet> createState() => _FulfillSheetState();
}

class _FulfillSheetState extends State<_FulfillSheet> {
  XFile? _photo;
  String? _uploadedUrl;
  bool _working = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pick(ImageSource source) async {
    if (_working) return;
    final xFile = await _picker.pickImage(
        source: source, maxWidth: 1600, imageQuality: 85);
    if (!mounted || xFile == null) return;
    setState(() { _photo = xFile; _uploadedUrl = null; });
  }

  Future<void> _submit() async {
    if (_working) return;
    setState(() => _working = true);
    final kitchen = context.read<KitchenProvider>();
    if (_photo != null && _uploadedUrl == null) {
      final (url, uploadErr) = await kitchen.uploadPhoto(_photo!.path);
      if (!mounted) return;
      if (uploadErr != null || url == null) {
        setState(() => _working = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(uploadErr ?? '上传失败，再试一次'),
            behavior: SnackBarBehavior.floating));
        return;
      }
      _uploadedUrl = url;
    }
    final err = await kitchen
        .updateOrderStatus(widget.order.id, 'done', extra: {...widget.order.expectedState, 'photo_url': _uploadedUrl});
    if (!mounted) return;
    setState(() => _working = false);
    if (err == null) Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? '已经开饭，记录已保存'),
        behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    // 订单 id 由打开方传入（通过 provider 暂存，见 _OrderCard 调用处）
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      // v4.0 弹层玻璃化统一口径（radiusXl 28 / 白 72% / blur 24）
      child: _KitchenGlassSheet(
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
            Text('开饭了，留下这一餐',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: context.lgTextPrimary)),
            const SizedBox(height: 4),
            Text('可以拍照留念，也可以直接完成。照片不是必填项。',
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
                text: _working ? '保存中…' : '确认开饭',
                onPressed: _working ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One explicit action per state; the accepted row keeps its undo action visible.
class _MealStatusButton extends StatelessWidget {
  final KitchenOrder order;
  final String status;
  final String text;
  final VoidCallback? onChanged;
  const _MealStatusButton({required this.order, required this.status, required this.text, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final kitchen = context.watch<KitchenProvider>();
    return TextButton(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      onPressed: kitchen.isOrderBusy(order.id) ? null : () async {
        final error = await kitchen.updateOrderStatus(order.id, status, extra: order.expectedState);
        if (!context.mounted) return;
        if (error == null) HapticFeedback.selectionClick();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error ?? (status == 'accepted' ? '已接下这一餐' : '已撤销接单，可以重新商量')),
          behavior: SnackBarBehavior.floating,
        ));
        if (error == null) onChanged?.call();
      },
      child: Text(kitchen.isOrderBusy(order.id) ? '处理中…' : text),
    );
  }
}
