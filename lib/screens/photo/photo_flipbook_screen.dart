import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:book_page_flip/book_page_flip.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/lovegirl_theme.dart';

/// 翻页相册：横屏摊开书浏览（选型定稿 book_page_flip，2026-09-19 真机择优）。
/// 照片由用户在"选片"面板手动挑选并按点选顺序装订（隐私约束：AI 不参与挑选）。

/// 引擎要求所有页同尺寸：照片解码后统一合成到该尺寸纸面画布（contain），
/// 原图比例不同则留纸色边，避免拉伸变形。
const int _kPageW = 720;
const int _kPageH = 960;

/// 翻页相册：照片以 3D 翻页书的方式浏览
class PhotoFlipbookScreen extends StatefulWidget {
  final List<String> photoUrls;
  final String title;

  const PhotoFlipbookScreen({
    super.key,
    required this.photoUrls,
    this.title = '翻页相册',
  });

  @override
  State<PhotoFlipbookScreen> createState() => _PhotoFlipbookScreenState();
}

class _PhotoFlipbookScreenState extends State<PhotoFlipbookScreen> {
  /// 当前书页使用的照片（已按用户选定顺序）
  late List<String> _bookUrls = List.of(widget.photoUrls);
  final List<ui.Image> _images = [];
  String? _error;
  bool _loading = true;
  int _loaded = 0;
  int _spread = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _decodeAll();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    for (final image in _images) {
      image.dispose();
    }
    super.dispose();
  }

  Future<void> _decodeAll() async {
    setState(() {
      _loading = true;
      _error = null;
      _spread = 0;
    });
    final images = <ui.Image>[];
    for (final raw in _bookUrls) {
      try {
        final data = await NetworkAssetBundle(Uri.parse(raw)).load('');
        final codec =
            await ui.instantiateImageCodec(data.buffer.asUint8List(),
                targetWidth: 720);
        final frame = await codec.getNextFrame();
        final page = await _normalizeToPage(frame.image);
        frame.image.dispose();
        images.add(page);
        if (!mounted) return;
        setState(() => _loaded = images.length);
      } catch (e) {
        for (final img in images) {
          img.dispose();
        }
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = '有照片加载失败，点按重试';
        });
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _images
        ..forEach((img) => img.dispose())
        ..clear()
        ..addAll(images);
      _loading = false;
    });
  }

  /// 把任意比例的照片合成到统一尺寸的纸面画布上（contain 居中，留纸色边）
  Future<ui.Image> _normalizeToPage(ui.Image src) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final pageRect = ui.Rect.fromLTWH(
        0, 0, _kPageW.toDouble(), _kPageH.toDouble());
    canvas.drawRect(
        pageRect, ui.Paint()..color = LoveGirlTheme.paperWarm);
    final sw = src.width.toDouble();
    final sh = src.height.toDouble();
    final scale = math.min(_kPageW / sw, _kPageH / sh);
    final dst = ui.Rect.fromCenter(
      center: pageRect.center,
      width: sw * scale,
      height: sh * scale,
    );
    canvas.drawImageRect(
      src,
      ui.Rect.fromLTWH(0, 0, sw, sh),
      dst,
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    final out = await picture.toImage(_kPageW, _kPageH);
    picture.dispose();
    return out;
  }

  Future<void> _openPicker() async {
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: const Color(0xFF211C18),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PhotoPickerSheet(
        allUrls: widget.photoUrls,
        initialSelected: List.of(_bookUrls),
      ),
    );
    if (picked == null || !mounted) return;
    if (picked.length == _bookUrls.length &&
        listEquals(picked, _bookUrls)) {
      return;
    }
    if (picked.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('至少挑两张照片才能装订成册'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ));
      return;
    }
    setState(() {
      _bookUrls = picked;
      _loaded = 0;
    });
    await _decodeAll();
  }

  @override
  Widget build(BuildContext context) {
    final spreadTotal = (_bookUrls.length / 2).ceil();
    return Scaffold(
      backgroundColor: const Color(0xFF171310),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.title,
            style: const TextStyle(
                fontWeight: FontWeight.w900, color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _loading ? null : _openPicker,
            child: Text('选片',
                style: TextStyle(
                    color:
                        _loading ? Colors.white24 : Colors.white70)),
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white70),
                  const SizedBox(height: 14),
                  Text('正在装订相册 $_loaded/${_bookUrls.length}',
                      style: const TextStyle(color: Colors.white54)),
                ],
              ),
            )
          : _error != null
              ? GestureDetector(
                  onTap: _decodeAll,
                  child: Center(
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.white54)),
                  ),
                )
              : _images.length < 2
                  ? const Center(
                      child: Text('再上传一张照片就能翻开相册啦',
                          style: TextStyle(color: Colors.white54)),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                            child: BookFlip(
                              pages: _images,
                              onSpreadChanged: (spread) =>
                                  setState(() => _spread = spread),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, top: 4),
                          child: Text(
                            '跨页 ${_spread + 1}/$spreadTotal · 拖动书角翻页',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

/// 选片面板：网格点选，点选顺序即页序（徽标数字），用户完全手动
class _PhotoPickerSheet extends StatefulWidget {
  final List<String> allUrls;
  final List<String> initialSelected;

  const _PhotoPickerSheet({
    required this.allUrls,
    required this.initialSelected,
  });

  @override
  State<_PhotoPickerSheet> createState() => _PhotoPickerSheetState();
}

class _PhotoPickerSheetState extends State<_PhotoPickerSheet> {
  late List<String> _selected = List.of(widget.initialSelected);

  void _toggle(String url) {
    setState(() {
      if (_selected.contains(url)) {
        _selected.remove(url);
      } else {
        _selected.add(url);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // 横屏高度有限：网格高度随可用高度收缩，整板可滚动兜底
    final gridH = (mq.size.height * 0.40).clamp(160.0, 260.0);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('挑照片装订成册',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
                const SizedBox(width: 8),
                Text('点选顺序 = 页序',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12)),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      setState(() => _selected = List.of(widget.allUrls)),
                  child: const Text('全选',
                      style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: () => setState(() => _selected = []),
                  child: const Text('清空',
                      style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: gridH,
              child: GridView.builder(
                itemCount: widget.allUrls.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (context, i) {
                  final url = widget.allUrls[i];
                  final order = _selected.indexOf(url);
                  final picked = order >= 0;
                  return GestureDetector(
                    onTap: () => _toggle(url),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            color: picked
                                ? null
                                : Colors.black38,
                            colorBlendMode:
                                picked ? null : BlendMode.darken,
                          ),
                        ),
                        if (picked)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text('${order + 1}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black)),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _selected),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                child: Text('重新装订（已选 ${_selected.length} 张）'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
