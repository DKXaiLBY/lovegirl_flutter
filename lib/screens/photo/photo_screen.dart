import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';
import '../../services/log_service.dart';
import '../../utils/constants.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/app_icon.dart';
import 'photo_flipbook_screen.dart';

/// 云端相册 · 拍立得收集本
/// 纸感背景 + 两列拍立得流（随机小倾斜 + 底边日期）+ 翻转故事背卡 + 批量管理。
class PhotoScreen extends StatefulWidget {
  const PhotoScreen({super.key});

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _photos = [];
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPhotos() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res = await _api.getPhotos();
      final data = res.data['data'];
      _photos = (data is List)
          ? data.map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
      _error = null;
    } catch (e) {
      _error = extractServerMessage(e, fallback: '加载失败，下拉重试');
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _pickAndUpload() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      // 服务器接口：POST /api/photo/upload，multipart 字段名 file
      final res =
          await _api.upload('/api/photo/upload', file.path, fieldName: 'file');
      final data = res.data?['data'];
      final url = data is Map ? (data['url'] as String?) : null;
      if (!mounted) return;
      if (url != null && url.isNotEmpty) {
        LogService().userAction('相册:上传照片');
        await _loadPhotos();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('上传失败，请重试'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2)));
      }
    } catch (e) {
      LogService().error('Photo', '上传失败: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(extractServerMessage(e, fallback: '上传失败，请重试')),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2)));
    }
    if (mounted) setState(() => _uploading = false);
  }

  void _toggleSelect(int id) {
    setState(() {
      if (!_selectionMode) _selectionMode = true;
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll() {
    setState(() {
      for (final p in _photos) {
        final id = (p['id'] as num?)?.toInt();
        if (id != null) _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final n = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('删除 $n 张照片？',
            style: const TextStyle(fontSize: 16)),
        content: const Text('删除后不可恢复',
            style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('删除',
                  style: TextStyle(
                      color: LoveGirlTheme.red.withAlpha(230)))),
        ],
      ),
    );
    if (confirm != true) return;
    var failed = 0;
    for (final id in _selectedIds.toList()) {
      try {
        await _api.deletePhoto(id);
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(failed == 0 ? '已删除 $n 张' : '有 $failed 张删除失败'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 1),
    ));
    _exitSelectionMode();
    _loadPhotos();
  }

  String _handDate(dynamic createdAt) {
    final s = createdAt?.toString() ?? '';
    final d = DateTime.tryParse(s.replaceFirst(' ', 'T'));
    if (d == null) return '';
    return '${d.month}/${d.day}';
  }

  /// 故事背卡：正面照片预览，背面故事文字（可编辑保存）
  Future<void> _showStorySheet(Map<String, dynamic> photo) async {
    final id = (photo['id'] as num?)?.toInt() ?? 0;
    final descCtrl =
        TextEditingController(text: photo['description']?.toString() ?? '');
    final url = (photo['url'] ?? photo['image'] ?? '').toString();
    final fullUrl =
        url.startsWith('http') ? url : '${AppConstants.baseUrl}$url';
    var saving = false;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: LoveGirlTheme.bgLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: LoveGirlTheme.separator,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Container(
                    width: 220,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withAlpha(30),
                            blurRadius: 14,
                            offset: const Offset(0, 8)),
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: SizedBox(
                            height: 190,
                            width: double.infinity,
                            child: CachedNetworkImage(
                              imageUrl: fullUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  Container(color: context.lgBg),
                              errorWidget: (_, __, ___) => Container(
                                  color: context.lgBg,
                                  child: const Icon(Icons.broken_image,
                                      color: LoveGirlTheme.textMuted)),
                            ),
                          ),
                        ),
                        Container(
                          height: 30,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _handDate(photo['created_at']),
                            style: const TextStyle(
                              fontSize: 19,
                              fontFamily: 'Caveat',
                              fontWeight: FontWeight.w700,
                              color: LoveGirlTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('这张照片背后的故事',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: '写点什么…（拍照那天的心情、当时的梗）',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: LoveGirlTheme.separator)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: LoveGirlTheme.separator)),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showFullScreen(url);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.lgInk,
                          side:
                              const BorderSide(color: LoveGirlTheme.separator),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('看大图',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: context.lgInk,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: saving
                            ? null
                            : () async {
                                setSheet(() => saving = true);
                                try {
                                  await _api.updatePhotoDescription(
                                      id, descCtrl.text.trim());
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                  if (!mounted) return;
                                  setState(() {
                                    photo['description'] = descCtrl.text.trim();
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('故事已保存'),
                                          behavior: SnackBarBehavior.floating,
                                          duration: Duration(seconds: 1)));
                                } catch (e) {
                                  if (!ctx.mounted) return;
                                  setSheet(() => saving = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                      content: Text(extractServerMessage(e,
                                          fallback: '保存失败，再试一次')),
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 1)));
                                }
                              },
                        child: Text(saving ? '保存中…' : '保存故事',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFullScreen(String url) {
    final fullUrl =
        url.startsWith('http') ? url : '${AppConstants.baseUrl}$url';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: fullUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image,
                    color: Colors.white54, size: 64),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectionMode) _exitSelectionMode();
      },
      child: Scaffold(
        backgroundColor: context.lgBg,
        appBar: _selectionMode ? _selectionAppBar() : _normalAppBar(),
        floatingActionButton: _selectionMode
            ? null
            : FloatingActionButton(
                backgroundColor: context.lgInk,
                foregroundColor: Colors.white,
                onPressed: _uploading ? null : _pickAndUpload,
                child: _uploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add_rounded, size: 28),
              ),
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/deco/paper_texture.png'),
              repeat: ImageRepeat.repeat,
              opacity: 0.55,
            ),
          ),
          child: _uploading && _photos.isEmpty
              ? const Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('正在上传...',
                          style: TextStyle(color: LoveGirlTheme.textMuted)),
                    ]))
              : _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? RefreshIndicator(
                          onRefresh: _loadPhotos,
                          child: ListView(children: [
                            SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.7,
                                child: _buildError())
                          ]),
                        )
                      : _photos.isEmpty
                          ? RefreshIndicator(
                              onRefresh: _loadPhotos,
                              child: ListView(children: [
                                SizedBox(
                                    height: MediaQuery.of(context)
                                            .size
                                            .height *
                                        0.7,
                                    child: _buildEmpty())
                              ]),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadPhotos,
                              child: GridView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    14, 10, 14, 90),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 18,
                                  crossAxisSpacing: 14,
                                  childAspectRatio: 0.72,
                                ),
                                itemCount: _photos.length,
                                itemBuilder: (context, index) {
                                  return _PolaroidTile(
                                    photo: _photos[index],
                                    rotation:
                                        _rotationFor(index, _photos.length),
                                    selectionMode: _selectionMode,
                                    selected: _selectedIds.contains(
                                        (_photos[index]['id'] as num?)
                                                ?.toInt() ??
                                            -1),
                                    onTapSelect: () => _toggleSelect(
                                        (_photos[index]['id'] as num?)
                                                ?.toInt() ??
                                            -1),
                                    onTapView: () => _showStorySheet(
                                        _photos[index]),
                                    onLongPress: () => _toggleSelect(
                                        (_photos[index]['id'] as num?)
                                                ?.toInt() ??
                                            -1),
                                  );
                                },
                              ),
                            ),
        ),
      ),
    );
  }

  /// 确定性伪随机倾斜：同一张照片每次角度相同（不闪烁），交替方向
  double _rotationFor(int index, int total) {
    final r = math.Random(index * 7 + total);
    return (r.nextDouble() * 2.4 - 1.2) * (index.isEven ? 1 : -1) / 57.3;
  }

  PreferredSizeWidget _normalAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: const Text('云端相册'),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: context.lgTextPrimary,
      ),
      leading: IconButton(
        icon: AppIcon('back'),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (_photos.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.checklist_rounded),
            tooltip: '批量管理',
            onPressed: () => setState(() => _selectionMode = true),
          ),
        if (_photos.isNotEmpty)
          IconButton(
            icon: AppIcon('auto_stories'),
            tooltip: '翻页书',
            onPressed: () {
              final urls = _photos
                  .map((p) => (p['url'] ?? p['image'] ?? '').toString())
                  .map((u) =>
                      u.startsWith('http') ? u : '${AppConstants.baseUrl}$u')
                  .toList();
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => PhotoFlipbookScreen(photoUrls: urls)),
              );
            },
          ),
      ],
    );
  }

  PreferredSizeWidget _selectionAppBar() {
    return AppBar(
      backgroundColor: context.lgInk,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: _exitSelectionMode,
      ),
      title: Text('已选 ${_selectedIds.length}',
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white)),
      actions: [
        TextButton(
            onPressed: _selectAll,
            child: const Text('全选',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800))),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          tooltip: '批量删除',
          onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 48, color: context.lgTextMuted),
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: context.lgTextSecondary)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _loadPhotos,
            icon: AppIcon('refresh'),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 14,
                      offset: const Offset(0, 8))
                ],
              ),
              padding: const EdgeInsets.all(10),
              child: Container(
                decoration: BoxDecoration(
                  color: LoveGirlTheme.primarySoft,
                  borderRadius: BorderRadius.circular(3),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.add_photo_alternate_outlined,
                    size: 34, color: LoveGirlTheme.textMuted),
              ),
            ),
            const Positioned(
                top: -8, right: -14, child: Text('✨', style: TextStyle(fontSize: 16))),
          ]),
          const SizedBox(height: 16),
          const Text('添加你的第一个故事',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('点右下角的 ＋ 上传一张照片',
              style: TextStyle(fontSize: 13, color: context.lgTextSecondary)),
        ],
      ),
    );
  }
}

/// 拍立得小卡：白框 + 方图 + 手写感日期 + 多选勾选
class _PolaroidTile extends StatelessWidget {
  final Map<String, dynamic> photo;
  final double rotation;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTapSelect;
  final VoidCallback onTapView;
  final VoidCallback onLongPress;

  const _PolaroidTile({
    required this.photo,
    required this.rotation,
    required this.selectionMode,
    required this.selected,
    required this.onTapSelect,
    required this.onTapView,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final url = (photo['url'] ?? photo['image'] ?? '').toString();
    final fullUrl = url.startsWith('http') ? url : '${AppConstants.baseUrl}$url';
    final desc = photo['description']?.toString() ?? '';

    return GestureDetector(
      onTap: selectionMode ? onTapSelect : onTapView,
      onLongPress: onLongPress,
      child: Transform.rotate(
        angle: selectionMode ? 0 : rotation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: selected
                ? Border.all(color: LoveGirlTheme.brandEmotion, width: 2.5)
                : Border.all(color: Colors.white),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(26),
                  blurRadius: 10,
                  offset: const Offset(0, 5)),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(7, 7, 7, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: CachedNetworkImage(
                        imageUrl: fullUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: context.lgBg),
                        errorWidget: (_, __, ___) => Container(
                          color: context.lgBg,
                          child: Icon(Icons.broken_image,
                              color: context.lgTextMuted),
                        ),
                      ),
                    ),
                    if (selectionMode)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? LoveGirlTheme.brandEmotion
                                : Colors.black.withAlpha(70),
                            border:
                                Border.all(color: Colors.white, width: 2),
                          ),
                          child: selected
                              ? const Icon(Icons.check_rounded,
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
              // 拍立得宽底边：手写感日期 + 有故事的标记
              Container(
                height: 34,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _handDate(photo['created_at']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          fontFamily: 'Caveat',
                          fontWeight: FontWeight.w700,
                          color: LoveGirlTheme.textSecondary,
                        ),
                      ),
                    ),
                    if (desc.isNotEmpty)
                      const Icon(Icons.sticky_note_2_outlined,
                          size: 12, color: LoveGirlTheme.textMuted),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _handDate(dynamic createdAt) {
    final s = createdAt?.toString() ?? '';
    final d = DateTime.tryParse(s.replaceFirst(' ', 'T'));
    if (d == null) return '';
    return '${d.month}/${d.day}';
  }
}

