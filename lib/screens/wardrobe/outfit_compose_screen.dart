import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/wardrobe.dart';
import '../../providers/wardrobe_provider.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/lovegirl_ui.dart';
import 'widgets/wardrobe_widgets.dart';

/// P5 组合搭配创建/编辑【M1】：选件面板（在柜、按类型分节）+ 底部托盘（≤8）
/// 校验 ≥2 件；日期默认今天可改未来=计划（≤今天+90）
class OutfitComposeScreen extends StatefulWidget {
  final List<int> preselect;
  final WardrobeOutfit? edit;

  const OutfitComposeScreen({super.key, this.preselect = const [], this.edit});

  @override
  State<OutfitComposeScreen> createState() => _OutfitComposeScreenState();
}

class _OutfitComposeScreenState extends State<OutfitComposeScreen> {
  final Set<int> _selected = {};
  late DateTime _date;
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.edit?.itemIds ?? widget.preselect);
    if (widget.edit != null) {
      final d = DateTime.tryParse(widget.edit!.wornDate);
      _date = d ?? DateTime.now();
      _noteCtrl.text = widget.edit!.note ?? '';
    } else {
      _date = DateTime.now();
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<WardrobeProvider>();
    final grouped = <String, List<WardrobeItem>>{};
    for (final cat in WardrobeTax.categories) {
      final list = p.inCabItems.where((e) => e.category == cat).toList();
      if (list.isNotEmpty) grouped[cat] = list;
    }

    return Scaffold(
      backgroundColor: context.lgBg,
      appBar: AppBar(
        backgroundColor: context.lgBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(_isEdit ? '编辑搭配' : '创建搭配',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.lgTextPrimary)),
      ),
      body: Column(
        children: [
          Expanded(
            child: p.inCabItems.isEmpty
                ? Center(
                    child: Text('衣橱里还没有在柜单品，先去添加吧',
                        style: TextStyle(
                            fontSize: 14, color: context.lgTextSecondary)))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    children: [
                      for (final entry in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 8),
                          child: Text('${entry.key}（${entry.value.length}）',
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: context.lgTextSecondary)),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final it in entry.value)
                              _pickable(it),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),
          _tray(p),
        ],
      ),
    );
  }

  Widget _pickable(WardrobeItem it) {
    final selected = _selected.contains(it.id);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (selected) {
            _selected.remove(it.id);
          } else if (_selected.length >= 8) {
            _toast('最多 8 件');
          } else {
            _selected.add(it.id);
          }
        });
      },
      child: SizedBox(
        width: 66,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? context.lgInk : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                        width: 62,
                        height: 62,
                        child: WnThumb(it.thumbnailUrl ?? it.imageUrl)),
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.lgInk,
                      ),
                      child: const Icon(Icons.check_rounded,
                          size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(it.brand?.isNotEmpty == true ? it.brand! : it.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10, color: context.lgTextSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _tray(WardrobeProvider p) {
    final picked = _selected.map((e) => p.itemById(e)).whereType<WardrobeItem>().toList();
    return SafeArea(
      top: false,
      child: LovePaper(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(12),
        radius: 18,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: picked.isEmpty ? 8 : 74,
              child: picked.isEmpty
                  ? Center(
                      child: Text('从上面点选 2-8 件，组成一套',
                          style: TextStyle(
                              fontSize: 12.5, color: context.lgTextMuted)))
                  : ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final it in picked)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _selected.remove(it.id)),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: WnThumb(
                                        it.thumbnailUrl ?? it.imageUrl,
                                        size: 66),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.black54),
                                      child: const Icon(Icons.close_rounded,
                                          size: 14, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.lgPrimarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      Icon(Icons.event_rounded,
                          size: 16, color: context.lgTextSecondary),
                      const SizedBox(width: 5),
                      Text(_fmt(_date),
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: context.lgTextPrimary)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _noteCtrl,
                    maxLength: 200,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      counterText: '',
                      isDense: true,
                      hintText: '备注（选填）',
                      filled: true,
                      fillColor: context.lgPrimarySoft,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                LovePrimaryButton(
                  text: _saving ? '…' : '保存',
                  onPressed: (_saving || picked.length < 2) ? null : () => _save(p),
                ),
              ],
            ),
            if (picked.length < 2)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('至少选 2 件才能叫搭配',
                    style: TextStyle(fontSize: 11, color: context.lgTextMuted)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: today.add(const Duration(days: 90)), // 计划穿搭上限 今天+90
      helpText: '选穿着日期（未来=计划）',
    );
    if (picked != null) setState(() => _date = picked);
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save(WardrobeProvider p) async {
    setState(() => _saving = true);
    final err = _isEdit
        ? await p.updateOutfit(widget.edit!.id,
            wornDate: _fmt(_date), itemIds: _selected.toList(), note: _noteCtrl.text.trim())
        : await p.createOutfit(
            source: '组合',
            wornDate: _fmt(_date),
            itemIds: _selected.toList(),
            note: _noteCtrl.text.trim(),
          );
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      _toast(err);
      return;
    }
    Navigator.of(context).pop();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
