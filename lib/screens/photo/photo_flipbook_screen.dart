import 'dart:ui' as ui;

import 'package:book_page_flip/book_page_flip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show NetworkAssetBundle;

import '../../utils/constants.dart';
import '../../utils/lovegirl_theme.dart';

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
  final List<ui.Image> _images = [];
  String? _error;
  bool _loading = true;
  int _loaded = 0;

  @override
  void initState() {
    super.initState();
    _decodeAll();
  }

  Future<void> _decodeAll() async {
    setState(() {
      _loading = true;
      _error = null;
      _images.clear();
      _loaded = 0;
    });
    for (final raw in widget.photoUrls) {
      final url = raw.startsWith('http') ? raw : '${AppConstants.baseUrl}$raw';
      try {
        final data =
            (await NetworkAssetBundle(Uri.parse(url)).load('')).buffer.asUint8List();
        final codec = await ui.instantiateImageCodec(data,
            targetWidth: 720); // 控制纹理尺寸，避免超出 atlas 上限
        final frame = await codec.getNextFrame();
        _images.add(frame.image);
        if (mounted) setState(() => _loaded++);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = '有照片加载失败，点按重试';
        });
        return;
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final image in _images) {
      image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF171310),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171310),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.title,
            style: const TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: LoveGirlTheme.primary),
                  const SizedBox(height: 14),
                  Text('正在装订相册 $_loaded/${widget.photoUrls.length}',
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
                  : Center(
                      child: BookFlip(pages: _images),
                    ),
    );
  }
}
