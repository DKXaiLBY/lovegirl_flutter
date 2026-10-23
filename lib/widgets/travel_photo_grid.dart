import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/utils/constants.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import '../screens/travel/travel_album_picker.dart';

/// 旅行地点照片网格组件
class TravelPhotoGrid extends StatefulWidget {
  final int spotId;
  final bool editable;
  final bool editorial;

  const TravelPhotoGrid({
    super.key,
    required this.spotId,
    this.editable = true,
    this.editorial = false,
  });

  @override
  State<TravelPhotoGrid> createState() => _TravelPhotoGridState();
}

class _TravelPhotoGridState extends State<TravelPhotoGrid> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _photos = [];
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getTravelPhotos(widget.spotId);
      final data = res.data?['data'];
      if (data is! List) throw const FormatException('Invalid photo list');
      if (!mounted) return;
      _photos = data.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      if (!mounted) return;
      _error = extractServerMessage(e, fallback: '照片加载失败，请重试');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _linkAlbumPhoto() async {
    final linked = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => TravelAlbumPicker(
        spotId: widget.spotId,
        linkedPhotoIds: _photos
            .map((photo) =>
                int.tryParse(photo['source_photo_id']?.toString() ?? ''))
            .whereType<int>()
            .toSet(),
      ),
    ));
    if (linked == true && mounted) await _loadPhotos();
  }

  Future<void> _pickAndUpload() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;

      setState(() => _uploading = true);
      await _api.uploadTravelPhoto(widget.spotId, file.path);
      await _loadPhotos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('上传失败，请重试'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _deletePhoto(int photoId) async {
    final linked = _photos.any((photo) =>
        photo['id'].toString() == photoId.toString() &&
        photo['source_photo_id'] != null);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(linked ? '移出这次回忆' : '删除照片'),
        content: Text(linked ? '相册原图会保留，只移除这次关联。' : '确定删除这张地点照片吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(linked ? '移出' : '删除',
                style: TextStyle(color: LoveGirlTheme.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _api.deleteTravelPhoto(widget.spotId, photoId);
        await _loadPhotos();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('删除失败'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
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
                placeholder: (_, __) => Center(
                    child: CircularProgressIndicator(color: Colors.white)),
                errorWidget: (_, __, ___) =>
                    Icon(Icons.broken_image, color: Colors.white54, size: 64),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null)
          Row(children: [
            Expanded(
                child: Text(_error!,
                    style: TextStyle(color: context.lgTextSecondary))),
            TextButton(onPressed: _loadPhotos, child: const Text('重试')),
          ]),
        if (widget.editorial && _photos.isEmpty && _error == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('这次回忆还没有照片，可以从相册关联或添加新照片。',
                style: TextStyle(color: context.lgTextMuted, height: 1.6)),
          ),
        // 照片网格
        if (_photos.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.editorial ? 1 : 3,
              childAspectRatio: widget.editorial ? 4 / 3 : 1,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: _photos.length,
            itemBuilder: (context, index) {
              final photo = _photos[index];
              final url = photo['url'] ?? photo['image'] ?? '';
              final fullUrl =
                  url.startsWith('http') ? url : '${AppConstants.baseUrl}$url';
              final id = photo['id'];

              return GestureDetector(
                onTap: () => _showFullScreen(url),
                onLongPress: widget.editable && id != null
                    ? () => _deletePhoto(int.parse(id.toString()))
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: fullUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: context.lgBg),
                        errorWidget: (_, __, ___) => Container(
                          color: context.lgBg,
                          child: Icon(Icons.broken_image,
                              color: context.lgTextMuted),
                        ),
                      ),
                      // 删除按钮（编辑模式）
                      if (widget.editable)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: id != null
                                ? () => _deletePhoto(int.parse(id.toString()))
                                : null,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(100),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

        // 添加照片按钮
        if (widget.editable)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: _uploading ? null : _linkAlbumPhoto,
              style: OutlinedButton.styleFrom(
                  foregroundColor: context.lgInk,
                  side: BorderSide(color: context.lgCardBorder)),
              icon: Icon(Icons.photo_library_outlined, color: context.lgInk),
              label: const Text('关联相册照片'),
            ),
          ),
        if (widget.editable)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton.tonal(
              onPressed: _uploading ? null : _pickAndUpload,
              style: FilledButton.styleFrom(
                backgroundColor: context.lgPrimarySoft,
                foregroundColor: context.lgInk,
                minimumSize: const Size(double.infinity, 80),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: _uploading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_photo_alternate_outlined, color: context.lgInk),
                      const SizedBox(height: 4),
                      const Text('添加照片'),
                    ]),
            ),
          ),
      ],
    );
  }
}
