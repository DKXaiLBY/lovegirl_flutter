import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/utils/constants.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';

/// 旅行地点照片网格组件
class TravelPhotoGrid extends StatefulWidget {
  final int spotId;
  final bool editable;

  const TravelPhotoGrid({
    super.key,
    required this.spotId,
    this.editable = true,
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

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getTravelPhotos(widget.spotId);
      final data = res.data?['data'];
      _photos = (data is List)
          ? data.map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
    } catch (e) {
      _photos = [];
    }
    setState(() => _loading = false);
  }

  Future<void> _pickAndUpload() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (file == null) return;

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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('删除照片'),
        content: const Text('确定删除这张照片吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除',
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
                placeholder: (_, __) =>
                    const Center(child: CircularProgressIndicator(color: Colors.white)),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.broken_image, color: Colors.white54, size: 64),
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
        // 照片网格
        if (_photos.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: _photos.length,
            itemBuilder: (context, index) {
              final photo = _photos[index];
              final url = photo['url'] ?? photo['image'] ?? '';
              final fullUrl = url.startsWith('http')
                  ? url
                  : '${AppConstants.baseUrl}$url';
              final id = photo['id'];

              return GestureDetector(
                onTap: () => _showFullScreen(url),
                onLongPress:
                    widget.editable && id != null ? () => _deletePhoto(id) : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: fullUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: LoveGirlTheme.bgLight),
                        errorWidget: (_, __, ___) => Container(
                          color: LoveGirlTheme.bgLight,
                          child: const Icon(Icons.broken_image,
                              color: LoveGirlTheme.textMuted),
                        ),
                      ),
                      // 删除按钮（编辑模式）
                      if (widget.editable)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: id != null
                                ? () => _deletePhoto(id)
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
            child: GestureDetector(
              onTap: _uploading ? null : _pickAndUpload,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: LoveGirlTheme.bgLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: LoveGirlTheme.primary.withAlpha(40),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Center(
                  child: _uploading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                color: LoveGirlTheme.primary.withAlpha(150),
                                size: 24),
                            const SizedBox(height: 4),
                            Text('添加照片',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: LoveGirlTheme.primary
                                        .withAlpha(150))),
                          ],
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
