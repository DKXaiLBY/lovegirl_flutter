import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/memory_controls.dart';

class TravelAlbumPicker extends StatefulWidget {
  final int spotId;
  final Set<int> linkedPhotoIds;
  const TravelAlbumPicker({
    super.key,
    required this.spotId,
    required this.linkedPhotoIds,
  });

  @override
  State<TravelAlbumPicker> createState() => _TravelAlbumPickerState();
}

class _TravelAlbumPickerState extends State<TravelAlbumPicker> {
  final _api = ApiService();
  List<Map<String, dynamic>> _photos = [];
  String? _error;
  bool _loading = true;
  bool _linking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getTravelAlbumPhotos(widget.spotId);
      final data = res.data['data'];
      if (data is! List) throw const FormatException('Invalid photo list');
      if (!mounted) return;
      _photos = data
          .whereType<Map>()
          .map((photo) => Map<String, dynamic>.from(photo))
          .where((photo) => !widget.linkedPhotoIds
              .contains(int.tryParse(photo['id'].toString())))
          .toList();
    } catch (error) {
      if (!mounted) return;
      _error = extractServerMessage(error, fallback: '相册加载失败，请重试');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _link(int photoId) async {
    if (_linking) return;
    setState(() => _linking = true);
    try {
      await _api.linkTravelPhoto(widget.spotId, photoId);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(extractServerMessage(error, fallback: '关联失败，请重试'))));
      }
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_linking,
        child: Scaffold(
          backgroundColor: context.lgPaper,
          appBar: AppBar(
            automaticallyImplyLeading: !_linking,
            title: Text(_linking ? '正在关联照片' : '选择相册照片'),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: MemoryAction(
                          icon: Icons.refresh,
                          label: _error!,
                          onPressed: _load))
                  : _photos.isEmpty
                      ? const Center(child: Text('暂无可关联照片，可先在相册上传'))
                      : Column(children: [
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('选择一张共享照片加入回忆，原图仍保留在相册；当前伴侣可在这次回忆中查看。'),
                          ),
                          if (_linking) const LinearProgressIndicator(),
                          Expanded(
                              child: GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8),
                            itemCount: _photos.length,
                            itemBuilder: (context, index) {
                              final photo = _photos[index];
                              final id = int.tryParse(photo['id'].toString());
                              final url = photo['url']?.toString() ?? '';
                              return Semantics(
                                button: true,
                                label: '关联第 ${index + 1} 张照片',
                                child: Material(
                                  clipBehavior: Clip.antiAlias,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Ink.image(
                                    image: CachedNetworkImageProvider(
                                        url.startsWith('http')
                                            ? url
                                            : AppConstants.baseUrl + url),
                                    fit: BoxFit.cover,
                                    child: InkWell(
                                        onTap: _linking || id == null
                                            ? null
                                            : () => _link(id)),
                                  ),
                                ),
                              );
                            },
                          )),
                        ]),
        ),
      );
}
