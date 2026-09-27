import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/wardrobe.dart';
import '../../providers/wardrobe_provider.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/lovegirl_ui.dart';
import 'widgets/wardrobe_widgets.dart';

/// P6 实拍记录【M1】：拍照/选图（原比例仅压缩）→ 日期（上限今天）→ 备注 →
/// 可选关联在柜单品 → 保存即已通过（实拍是既成事实，决策 Q3）
class OutfitCaptureScreen extends StatefulWidget {
  final WardrobeOutfit? edit; // 编辑实拍：换图/日期/备注/关联

  const OutfitCaptureScreen({super.key, this.edit});

  @override
  State<OutfitCaptureScreen> createState() => _OutfitCaptureScreenState();
}

class _OutfitCaptureScreenState extends State<OutfitCaptureScreen> {
  File? _photo;
  late DateTime _date;
  final _noteCtrl = TextEditingController();
  final Set<int> _linked = {};
  bool _saving = false;

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    _date = DateTime.tryParse(widget.edit?.wornDate ?? '') ?? DateTime.now();
    if (widget.edit != null) {
      _linked.addAll(widget.edit!.itemIds);
      _noteCtrl.text = widget.edit!.note ?? '';
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
    return Scaffold(
      backgroundColor: context.lgBg,
      appBar: AppBar(
        backgroundColor: context.lgBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(_isEdit ? '编辑实拍' : '记录今天穿搭',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.lgTextPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _photoArea(),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('穿着日期',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: context.lgTextSecondary)),
              const Spacer(),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.lgSeparator),
                  ),
                  child: Row(children: [
                    Icon(Icons.event_rounded,
                        size: 15, color: context.lgTextSecondary),
                    const SizedBox(width: 5),
                    Text(_fmt(_date),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.lgTextPrimary)),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('关联单品（选填）',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: context.lgTextSecondary)),
              const Spacer(),
              GestureDetector(
                onTap: () => _pickLinked(p),
                child: Text(_linked.isEmpty ? '+ 关联' : '改关联 (${_linked.length})',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: context.lgInk)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_linked.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in _linked)
                  Builder(builder: (_) {
                    final it = p.itemById(id);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: context.lgPrimarySoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                          it == null
                              ? '已删除'
                              : (it.brand?.isNotEmpty == true
                                  ? it.brand!
                                  : it.category),
                          style: TextStyle(
                              fontSize: 12, color: context.lgTextSecondary)),
                    );
                  }),
              ],
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteCtrl,
            maxLength: 200,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              counterText: '',
              hintText: '今天的穿搭心情…（选填）',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.lgSeparator)),
            ),
          ),
          const SizedBox(height: 22),
          LovePrimaryButton(
            text: _saving ? '保存中…' : '记录下来',
            onPressed: _saving ? null : () => _save(p),
          ),
        ],
      ),
    );
  }

  Widget _photoArea() {
    return LovePaper(
      padding: EdgeInsets.zero,
      radius: 18,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_photo != null)
                Image.file(_photo!, fit: BoxFit.cover)
              else if (_isEdit && widget.edit!.photoUrl != null)
                WnThumb(widget.edit!.photoUrl)
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt_rounded,
                          size: 42, color: context.lgTextMuted),
                      const SizedBox(height: 8),
                      Text('拍下今天的穿搭',
                          style: TextStyle(
                              fontSize: 12.5, color: context.lgTextMuted)),
                    ],
                  ),
                ),
              Positioned(
                right: 10,
                bottom: 10,
                child: Row(children: [
                  _btn(Icons.photo_camera_rounded, () => _pick(ImageSource.camera)),
                  const SizedBox(width: 8),
                  _btn(Icons.photo_library_rounded, () => _pick(ImageSource.gallery)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Future<void> _pick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 90);
    if (picked == null) return;
    setState(() => _photo = File(picked.path)); // 实拍保持原比例，不裁剪（决策 D1）
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(today) ? today : _date,
      firstDate: DateTime(2000),
      lastDate: today, // 实拍是已穿事实：上限今天（决策 Q3 配套）
      helpText: '穿的日期（可补记过去）',
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _pickLinked(WardrobeProvider p) {
    final pool = p.inCabItems;
    final temp = Set<int>.from(_linked);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.65),
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.lgCard,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text('关联衣柜单品（可跳过）',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: context.lgTextPrimary)),
              const SizedBox(height: 10),
              Expanded(
                child: StatefulBuilder(
                  builder: (ctx, setSheetState) => pool.isEmpty
                      ? Center(
                          child: Text('衣橱还没有在柜单品',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: context.lgTextMuted)))
                      : SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final it in pool)
                                WnChip(
                                  it.brand?.isNotEmpty == true
                                      ? '${it.category}·${it.brand}'
                                      : it.category,
                                  selected: temp.contains(it.id),
                                  onTap: () => setSheetState(() =>
                                      temp.contains(it.id)
                                          ? temp.remove(it.id)
                                          : temp.add(it.id)),
                                ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: LovePrimaryButton(
                  text: '好了',
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    setState(() => _linked
                      ..clear()
                      ..addAll(temp));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save(WardrobeProvider p) async {
    if (!_isEdit && _photo == null) {
      _toast('先拍一张今天的穿搭吧');
      return;
    }
    setState(() => _saving = true);
    final err = _isEdit
        ? await p.updateOutfit(widget.edit!.id,
            filePath: _photo?.path,
            wornDate: _fmt(_date),
            itemIds: _linked.toList(),
            note: _noteCtrl.text.trim())
        : await p.createOutfit(
            filePath: _photo!.path,
            source: '实拍',
            wornDate: _fmt(_date),
            itemIds: _linked.toList(),
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
