import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/kitchen_provider.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/rebuild_controls.dart';
import 'kitchen_meal_fields.dart';

bool canAdjustKitchenMeal(KitchenProvider kitchen, KitchenOrder order) {
  final participants = {order.ordererId, order.partnerId ?? order.cookId};
  return order.isActive &&
      kitchen.bound &&
      kitchen.accountId != kitchen.partnerId &&
      participants.contains(kitchen.accountId) &&
      participants.contains(kitchen.partnerId);
}

Future<bool?> showKitchenMealEditor(BuildContext context, int id) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _KitchenMealEditor(id: id),
    );

class _KitchenMealEditor extends StatefulWidget {
  final int id;
  const _KitchenMealEditor({required this.id});
  @override
  State<_KitchenMealEditor> createState() => _KitchenMealEditorState();
}

class _KitchenMealEditorState extends State<_KitchenMealEditor> {
  KitchenOrder? _base;
  final _note = TextEditingController();
  final _items = <int, int>{};
  int? _chef;
  String? _date, _slot, _error;
  bool _loading = true, _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final kitchen = context.read<KitchenProvider>();
    setState(() {
      _loading = true;
      _error = null;
    });
    if (!kitchen.menuLoaded) await kitchen.loadMenu(silent: true);
    if (!mounted) return;
    final (order, error) = await kitchen.getOrder(widget.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
      if (order != null) {
        _base = order;
        _chef = order.cookId;
        _date = order.mealDate;
        _slot = order.mealSlot;
        _note.text = order.note ?? '';
        _items
          ..clear()
          ..addEntries(
              order.items.map((item) => MapEntry(item.dishId, item.quantity)));
      }
    });
  }

  Future<void> _readLatest() async {
    if (_base != null) {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
                title: const Text('读取最新餐次'),
                content: const Text('读取成功后会替换尚未保存的修改。'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('继续编辑')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('读取最新'))
                ],
              ));
      if (!mounted || confirmed != true) return;
    }
    await _load();
  }

  Future<void> _changeChef(int? chef) async {
    if (chef == null || chef == _chef) return;
    if (_items.isNotEmpty) {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
                title: const Text('更换主厨'),
                content: const Text('更换后需要从新主厨的菜单重新选菜。'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('保留选菜')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('更换主厨'))
                ],
              ));
      if (!mounted || confirmed != true) return;
    }
    setState(() {
      _chef = chef;
      _items.clear();
    });
  }

  Future<void> _save() async {
    final base = _base;
    if (base == null || _saving || _chef == null || _items.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final kitchen = context.read<KitchenProvider>();
    final error = await kitchen.updateOrder(base.id, {
      'revision': base.revision,
      'cook_id': _chef,
      'meal_date': _date,
      'meal_slot': _slot,
      'note': _note.text.trim(),
      'items': _items.entries
          .map((entry) => {'dish_id': entry.key, 'quantity': entry.value})
          .toList(),
    });
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = error;
    });
    if (error == null) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final kitchen = context.watch<KitchenProvider>();
    final base = _base;
    final enabled = !_loading &&
        !_saving &&
        base != null &&
        canAdjustKitchenMeal(kitchen, base);
    final menu =
        _chef == kitchen.accountId ? kitchen.mine : kitchen.partnerDishes;
    final original = {
      if (base?.cookId == _chef && base != null)
        for (final item in base.items) item.dishId: item
    };
    final choices = <int, (String, bool)>{
      for (final dish in menu)
        dish.id: (original[dish.id]?.name ?? dish.name, true),
      for (final entry in original.entries)
        if (!menu.any((dish) => dish.id == entry.key))
          entry.key: (entry.value.name, false),
    };
    final chefs = <int>{
      if (kitchen.accountId != null) kitchen.accountId!,
      if (kitchen.partnerId != null) kitchen.partnerId!
    };
    return PopScope(
        canPop: !_saving,
        child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('调整这一餐',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text('保存后由主厨重新确认。',
                          style: TextStyle(color: context.lgTextMuted)),
                      if (_loading) const LinearProgressIndicator(),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!),
                        TextButton(
                            onPressed: _loading || _saving ? null : _readLatest,
                            child: const Text('读取最新餐次')),
                      ],
                      if (base != null) ...[
                        const SizedBox(height: 14),
                        if (!canAdjustKitchenMeal(kitchen, base))
                          const Text('当前餐次不可调整。'),
                        DropdownButtonFormField<int>(
                            value: chefs.contains(_chef) ? _chef : null,
                            decoration: const InputDecoration(labelText: '主厨'),
                            items: [
                              for (final chef in chefs)
                                DropdownMenuItem(
                                    value: chef,
                                    child: Text(chef == kitchen.accountId
                                        ? '我来掌勺'
                                        : '${kitchen.partnerName ?? 'TA'}来掌勺'))
                            ],
                            onChanged: enabled ? _changeChef : null),
                        const SizedBox(height: 12),
                        if (choices.isEmpty)
                          const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('主厨的菜单暂时没有可选菜品。')),
                        for (final entry in choices.entries)
                          _dishRow(entry.key, entry.value, enabled),
                        const SizedBox(height: 12),
                        KitchenMealFields(
                            date: _date,
                            slot: _slot,
                            enabled: enabled,
                            onDate: (date) => setState(() => _date = date),
                            onSlot: (slot) => setState(() => _slot = slot)),
                        const SizedBox(height: 12),
                        TextField(
                            controller: _note,
                            maxLength: 300,
                            maxLines: 3,
                            minLines: 1,
                            enabled: enabled,
                            decoration:
                                const InputDecoration(labelText: '口味与备注')),
                        const SizedBox(height: 12),
                        SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                                style: rebuildFilledStyle(context),
                                onPressed:
                                    enabled && _items.isNotEmpty ? _save : null,
                                child: Text(_saving ? '保存中…' : '保存调整'))),
                      ],
                    ],
                  ))),
        ));
  }

  Widget _dishRow(int id, (String, bool) entry, bool enabled) {
    final qty = _items[id] ?? 0;
    return Row(children: [
      Expanded(child: Text(entry.$2 ? entry.$1 : '${entry.$1}（已下架）')),
      if (!entry.$2)
        TextButton(
            onPressed: enabled && qty > 0
                ? () => setState(() => _items.remove(id))
                : null,
            child: Text(qty > 0 ? '移除 $qty 份' : '已移除'))
      else ...[
        IconButton(
            tooltip: '减少${entry.$1}',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: !enabled || qty == 0
                ? null
                : () => setState(() {
                      if (qty == 1) {
                        _items.remove(id);
                      } else {
                        _items[id] = qty - 1;
                      }
                    }),
            icon: const Icon(Icons.remove_rounded)),
        Text('$qty'),
        IconButton(
            tooltip: '增加${entry.$1}',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: !enabled || qty >= 9 || (qty == 0 && _items.length >= 20)
                ? null
                : () => setState(() => _items[id] = qty + 1),
            icon: const Icon(Icons.add_rounded)),
      ],
    ]);
  }
}
