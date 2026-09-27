import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../models/wardrobe.dart';
import '../../providers/wardrobe_provider.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/lovegirl_ui.dart';
import 'widgets/wardrobe_widgets.dart';

/// P2 添加单品 / P4 编辑单品【M1】
/// 流程：取图 → 1:1 裁剪（决策 R3）→ 压长边 1600 →（抠图，S3 关闭时隐藏）→ 表单
class WardrobeItemFormScreen extends StatefulWidget {
  final WardrobeItem? edit;

  const WardrobeItemFormScreen({super.key, this.edit});

  @override
  State<WardrobeItemFormScreen> createState() => _WardrobeItemFormScreenState();
}

class _WardrobeItemFormScreenState extends State<WardrobeItemFormScreen> {
  File? _imageFile;
  bool _saving = false;

  String? _category;
  String? _temperature;
  String? _color;
  final Set<String> _occasions = {};
  final Set<String> _styles = {};
  final _brandCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      _category = e.category;
      _temperature = e.temperature;
      _color = e.color;
      _occasions.addAll(e.occasions);
      _styles.addAll(e.styles);
      _brandCtrl.text = e.brand ?? '';
      _priceCtrl.text = e.price?.toString() ?? '';
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _category = context.read<WardrobeProvider>().lastCategory);
      });
    }
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _priceCtrl.dispose();
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
        title: Text(_isEdit ? '编辑单品' : '添加单品',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.lgTextPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _imageArea(p),
          const SizedBox(height: 18),
          _label('类型 *'),
          WnChipGroup(
            options: WardrobeTax.categories,
            selected: {_category ?? ''},
            onToggle: (o) => setState(() => _category = o),
          ),
          const SizedBox(height: 16),
          _label('适合温度'),
          WnChipGroup(
            options: WardrobeTax.temperatures,
            selected: {_temperature ?? ''},
            onToggle: (o) => setState(() => _temperature = _temperature == o ? null : o),
          ),
          const SizedBox(height: 16),
          _label('主色'),
          WnChipGroup(
            options: WardrobeTax.colors,
            selected: {_color ?? ''},
            onToggle: (o) => setState(() => _color = _color == o ? null : o),
          ),
          const SizedBox(height: 16),
          _label('场合'),
          WnChipGroup(
            options: WardrobeTax.occasions,
            selected: _occasions,
            onToggle: (o) => setState(() =>
                _occasions.contains(o) ? _occasions.remove(o) : _occasions.add(o)),
          ),
          const SizedBox(height: 16),
          _label('风格'),
          WnChipGroup(
            options: WardrobeTax.styles,
            selected: _styles,
            onToggle: (o) => setState(() => _styles.contains(o) ? _styles.remove(o) : _styles.add(o)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _brandCtrl,
                  maxLength: 20,
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: '品牌（选填）',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.lgSeparator)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '价格 ¥（选填）',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.lgSeparator)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LovePrimaryButton(
            text: _saving ? '保存中…' : (_isEdit ? '保存修改' : '放入衣橱'),
            onPressed: _saving ? null : () => _save(p),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: context.lgTextSecondary)),
      );

  Widget _imageArea(WardrobeProvider p) {
    return LovePaper(
      padding: EdgeInsets.zero,
      radius: 18,
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_imageFile != null)
                Image.file(_imageFile!, fit: BoxFit.cover)
              else if (_isEdit)
                WnThumb(widget.edit!.imageUrl)
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_a_photo_rounded,
                          size: 42, color: context.lgTextMuted),
                      const SizedBox(height: 8),
                      Text('拍一张或从相册选（方形裁剪）',
                          style: TextStyle(
                              fontSize: 12.5, color: context.lgTextMuted)),
                    ],
                  ),
                ),
              Positioned(
                right: 10,
                bottom: 10,
                child: Row(
                  children: [
                    _imgBtn(Icons.photo_camera_rounded, () => _pick(ImageSource.camera)),
                    const SizedBox(width: 8),
                    _imgBtn(Icons.photo_library_rounded, () => _pick(ImageSource.gallery)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imgBtn(IconData icon, VoidCallback onTap) {
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
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 95);
    if (picked == null) return;
    final cropped = await _crop1x1(picked.path);
    final compressed = await _compress(cropped);
    if (compressed != null && mounted) setState(() => _imageFile = compressed);
  }

  /// 1:1 裁剪；裁剪器异常时优雅回退原图（老设备兼容，风险 R2）
  Future<String> _crop1x1(String path) async {
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '裁成方形',
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(title: '裁成方形', aspectRatioLockEnabled: true),
        ],
      );
      return cropped?.path ?? path;
    } catch (_) {
      return path;
    }
  }

  /// 压长边 1600（§0 图片约定）；失败回退原图
  Future<File?> _compress(String path) async {
    try {
      final bytes = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: 1600,
        minHeight: 1600,
        quality: 85,
        format: CompressFormat.jpeg,
      );
      if (bytes == null) return File(path);
      final dir = await getTemporaryDirectory();
      final out = File('${dir.path}/wn_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await out.writeAsBytes(bytes);
      return out;
    } catch (_) {
      return File(path);
    }
  }

  Future<void> _save(WardrobeProvider p) async {
    if (!_isEdit && _imageFile == null) {
      _toast('先给衣服拍张照吧');
      return;
    }
    if (_category == null) {
      _toast('选一下类型（必填）');
      return;
    }
    setState(() => _saving = true);
    final err = await (_isEdit
        ? p.updateItem(
            widget.edit!.id,
            filePath: _imageFile?.path,
            category: _category!,
            temperature: _temperature,
            color: _color,
            occasions: _occasions.toList(),
            styles: _styles.toList(),
            brand: _brandCtrl.text.trim(),
            price: _priceCtrl.text.trim(),
          )
        : p.addItem(
            filePath: _imageFile!.path,
            category: _category!,
            temperature: _temperature,
            color: _color,
            occasions: _occasions.toList(),
            styles: _styles.toList(),
            brand: _brandCtrl.text.trim(),
            price: _priceCtrl.text.trim(),
          ));
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
