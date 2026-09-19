import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:book_page_flip/book_page_flip.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show NetworkAssetBundle;
import 'package:page_flip/page_flip.dart';

import '../../utils/constants.dart';
import '../../utils/lovegirl_theme.dart';

/// 翻页相册·选型对比页（BACKLOG 翻页相册轮）：
/// 同一批照片在两个候选引擎间切换，真机对比手感后择优保留。
/// A = book_page_flip（摊开书跨页，预解码位图）
/// B = page_flip（单页翻动，widget 直接当页）

/// A 引擎要求所有页同尺寸：照片解码后统一合成到该尺寸纸面画布（contain），
/// 原图比例不同则留纸色边，避免拉伸变形。
const int _kPageW = 720;
const int _kPageH = 960;
enum _FlipEngine { bookPageFlip, pageFlip }

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
  final GlobalKey<PageFlipWidgetState> _pageFlipKey = GlobalKey();
  String? _error;
  bool _loading = true;
  int _loaded = 0;
  _FlipEngine _engine = _FlipEngine.bookPageFlip;
  int _position = 1; // A=跨页序号 / B=页码，均从 1 起

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
      final url = _absoluteUrl(raw);
      try {
        final data =
            (await NetworkAssetBundle(Uri.parse(url)).load('')).buffer.asUint8List();
        final codec = await ui.instantiateImageCodec(data,
            targetWidth: 720); // 控制解码尺寸，合成前足够清晰即可
        final frame = await codec.getNextFrame();
        final page = await _normalizeToPage(frame.image);
        frame.image.dispose();
        _images.add(page);
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

  String _absoluteUrl(String raw) =>
      raw.startsWith('http') ? raw : '${AppConstants.baseUrl}$raw';

  int get _spreadTotal => (_images.length / 2).ceil();

  void _switchEngine(_FlipEngine e) {
    if (e == _engine) return;
    setState(() {
      _engine = e;
      _position = 1;
    });
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
            style: const TextStyle(
                fontWeight: FontWeight.w900, color: Colors.white)),
        centerTitle: true,
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white70),
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
                  : Column(
                      children: [
                        Expanded(child: _buildBook()),
                        _buildCompareBar(),
                      ],
                    ),
    );
  }

  Widget _buildBook() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Center(
        child: _engine == _FlipEngine.bookPageFlip
            ? BookFlip(
                pages: _images,
                onSpreadChanged: (spread) =>
                    setState(() => _position = spread + 1),
              )
            : PageFlipWidget(
                key: _pageFlipKey,
                backgroundColor: const Color(0xFF171310),
                onPageFlipped: (page) => setState(() {
                  _position = (page + 1).clamp(1, widget.photoUrls.length);
                }),
                lastPage: Container(
                  color: LoveGirlTheme.paperWarm,
                  alignment: Alignment.center,
                  child: const Text('— 未完待续 —',
                      style: TextStyle(color: LoveGirlTheme.textMuted)),
                ),
                children: [
                  for (final raw in widget.photoUrls)
                    Image(
                      image: CachedNetworkImageProvider(_absoluteUrl(raw)),
                      fit: BoxFit.cover,
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildCompareBar() {
    final isSpread = _engine == _FlipEngine.bookPageFlip;
    final total = isSpread ? _spreadTotal : widget.photoUrls.length;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isSpread ? '跨页 $_position/$total' : '第 $_position/$total 张',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            SegmentedButton<_FlipEngine>(
              segments: const [
                ButtonSegment(
                    value: _FlipEngine.bookPageFlip,
                    label: Text('A book_page_flip')),
                ButtonSegment(
                    value: _FlipEngine.pageFlip, label: Text('B page_flip')),
              ],
              selected: {_engine},
              onSelectionChanged: (sel) => _switchEngine(sel.first),
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: Colors.white,
                selectedForegroundColor: Colors.black,
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white60,
                side: const BorderSide(color: Colors.white24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
