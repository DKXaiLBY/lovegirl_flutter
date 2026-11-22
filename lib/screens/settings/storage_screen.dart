import 'package:flutter/material.dart';

import '../../services/app_storage.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/rebuild_controls.dart';
import 'package:lovegirl_flutter/widgets/glass_routes.dart';

class StorageScreen extends StatefulWidget {
  final int? account;
  const StorageScreen({super.key, required this.account});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  late Future<StorageSnapshot> _stats = AppStorage.read(widget.account);
  bool _clearing = false;

  void _reload() => setState(() => _stats = AppStorage.read(widget.account));

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => GlassAlertDialog(
        title: const Text('清理可重新下载的缓存？'),
        content: const Text('会移除媒体缓存和过期的临时导出文件。相册、作品及本机草稿会保留。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('清理')),
        ],
      ),
    );
    if (confirmed != true || !mounted || _clearing) return;
    setState(() => _clearing = true);
    try {
      await AppStorage.clearMediaAndExpiredExports();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('缓存已清理')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('部分缓存暂时无法清理，请稍后重试')));
      }
    } finally {
      if (mounted) {
        _clearing = false;
        _reload();
      }
    }
  }

  String _size(int bytes) => bytes < 1024
      ? '$bytes B'
      : bytes < 1024 * 1024
          ? '${(bytes / 1024).toStringAsFixed(1)} KB'
          : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          flexibleSpace: const RebuildGlassHeader(),
          title: const Text('数据管理'),
          actions: [
            IconButton(
                onPressed: _reload,
                tooltip: '重新统计',
                icon: const Icon(Icons.refresh))
          ],
        ),
        body: RebuildPageBackground(
          child: SafeArea(
              top: false,
              child: FutureBuilder<StorageSnapshot>(
                future: _stats,
                builder: (context, state) {
                  final data = state.data;
                  if (data == null) {
                    return Center(
                        child: state.hasError
                            ? TextButton(
                                onPressed: _reload,
                                child: const Text('统计失败，重试'))
                            : const CircularProgressIndicator());
                  }
                  return ListView(padding: const EdgeInsets.all(16), children: [
                    RebuildGlass(
                        radius: 22,
                        child: Column(children: [
                          for (final item in [
                            ('媒体缓存', data.media, '用于加快照片和作品的浏览'),
                            ('更新安装包', data.updates, '确认升级成功后自动回收'),
                            ('临时导出', data.exports, '用于导出期间中转'),
                            ('本机草稿', data.drafts, '清理缓存时保留'),
                          ])
                            ListTile(
                              title: Text(item.$1),
                              subtitle: Text(item.$3),
                              trailing: Text(_size(item.$2),
                                  style: TextStyle(
                                      color: context.lgTextSecondary)),
                            ),
                        ])),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: _clearing ? null : _clear,
                        style: rebuildFilledStyle(context),
                        child: Text(_clearing ? '正在清理…' : '清理缓存')),
                  ]);
                },
              )),
        ),
      );
}
