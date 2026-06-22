import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../utils/lovegirl_theme.dart';

/// 云端相册页面
class PhotoScreen extends StatefulWidget {
  const PhotoScreen({super.key});

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _photos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getPhotos();
      final data = res.data['data'];
      _photos = (data is List)
          ? data.map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
    } catch (e) {
      _error = '加载失败，下拉重试';
    }
    setState(() => _loading = false);
  }

  Future<void> _deletePhoto(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('删除照片'),
        content: const Text('确定删除这张照片吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: LoveGirlTheme.pink)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _api.deletePhoto(id);
        await _loadPhotos();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除失败'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2)),
          );
        }
      }
    }
  }

  void _showFullScreen(String url) {
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
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LoveGirlTheme.bgLight,
      appBar: AppBar(
        title: const Text('云端相册'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _photos.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _loadPhotos,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(4),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                        itemCount: _photos.length,
                        itemBuilder: (context, index) {
                          final photo = _photos[index];
                          final url = photo['url'] ?? photo['image'] ?? '';
                          final id = photo['id'];
                          return GestureDetector(
                            onTap: () => _showFullScreen(url),
                            onLongPress: () => id != null ? _deletePhoto(id) : null,
                            child: CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: LoveGirlTheme.bgLight),
                              errorWidget: (_, __, ___) => Container(
                                color: LoveGirlTheme.bgLight,
                                child: const Icon(Icons.broken_image, color: LoveGirlTheme.textMuted),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: LoveGirlTheme.textMuted),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: LoveGirlTheme.textSecondary)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _loadPhotos,
            icon: const Icon(Icons.refresh),
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
          const Icon(Icons.photo_library_outlined, size: 64, color: LoveGirlTheme.textMuted),
          const SizedBox(height: 12),
          const Text('还没有照片', style: TextStyle(fontSize: 16, color: LoveGirlTheme.textSecondary)),
          const Text('你们一起的照片会展示在这里', style: TextStyle(fontSize: 13, color: LoveGirlTheme.textMuted)),
        ],
      ),
    );
  }
}
