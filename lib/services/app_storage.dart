import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/constants.dart';
import 'log_service.dart';

const updateApkName = 'LoveGirl-latest.apk';

class MediaCache extends CacheManager with ImageCacheManager {
  static final instance = MediaCache._();
  static const diskBudget = 100 * 1024 * 1024;
  static const _idle = Duration(seconds: 5);
  static final _origin = Uri.parse(AppConstants.baseUrl);
  static const _authStorage = FlutterSecureStorage();

  MediaCache._() : super(Config(DefaultCacheManager.key));

  final _lastRead = <String, DateTime>{};
  Timer? _trimTimer;
  int _pendingImages = 0;
  Future<void> _maintenance = Future.value();
  int? _account;

  static bool isProtectedUri(Uri uri) =>
      uri.scheme == _origin.scheme &&
      uri.host == _origin.host &&
      uri.port == _origin.port &&
      uri.userInfo.isEmpty &&
      uri.path.startsWith('/uploads/');

  static Future<Map<String, String>> headersFor(Uri uri) async {
    if (!isProtectedUri(uri)) return const {};
    final token = await _authStorage.read(key: AppConstants.tokenKey);
    return token == null ? const {} : {'Authorization': 'Bearer $token'};
  }

  static ImageProvider image(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && isProtectedUri(uri)) {
      return CachedNetworkImageProvider(url, cacheManager: instance);
    }
    return NetworkImage(url);
  }

  void setAccount(int? account) {
    if (_account == account) return;
    _account = account;
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  }

  @override
  Stream<FileResponse> getImageFile(String url,
      {String? key,
      Map<String, String>? headers,
      bool withProgress = false,
      int? maxHeight,
      int? maxWidth}) async* {
    final uri = Uri.tryParse(url);
    final protected = uri != null && isProtectedUri(uri);
    final account = _account;
    if (protected) {
      if (account == null) return;
      final auth = await headersFor(uri);
      if (auth.isEmpty || account != _account) return;
      key = 'media-v2/$account/${key ?? url}';
      headers = {...?headers, ...auth};
    }
    _pendingImages++;
    var readImage = false;
    try {
      await for (final response in super.getImageFile(url,
          key: key,
          headers: headers,
          withProgress: withProgress,
          maxHeight: maxHeight,
          maxWidth: maxWidth)) {
        if (protected && account != _account) break;
        if (response is FileInfo) readImage = true;
        yield response;
      }
    } finally {
      _pendingImages--;
      if (readImage) scheduleTrim();
    }
  }

  @override
  Future<FileInfo?> getFileFromCache(String key,
      {bool ignoreMemCache = false}) async {
    final file =
        await super.getFileFromCache(key, ignoreMemCache: ignoreMemCache);
    if (file != null) _lastRead[key] = DateTime.now();
    return file;
  }

  void scheduleTrim() {
    _trimTimer ??= Timer(_idle, () async {
      _trimTimer = null;
      try {
        await _runMaintenance(_trimDisk);
      } catch (error) {
        LogService().error('Storage', '照片缓存整理失败: $error');
      }
    });
  }

  Future<Directory> directory() async => Directory(
      '${(await getTemporaryDirectory()).path}/${DefaultCacheManager.key}');

  Future<void> _runMaintenance(Future<void> Function() action) {
    final next = _maintenance.then((_) => action());
    _maintenance = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  Stream<File> _diskFiles() async* {
    final folder = await directory();
    if (!await folder.exists()) return;
    await for (final entry in folder.list(followLinks: false)) {
      if (entry is File) yield entry;
    }
  }

  Future<void> _trimDisk() async {
    if (_pendingImages > 0) {
      scheduleTrim();
      return;
    }
    final objects = {
      for (final object in await config.repo.getAllObjects())
        object.relativePath: object,
    };
    final now = DateTime.now();
    _lastRead.removeWhere((key, last) => now.difference(last).inMinutes > 2);
    final entries =
        <({File file, String? key, DateTime used, FileStat stat})>[];
    var bytes = 0;
    await for (final file in _diskFiles()) {
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file) continue;
      final object = objects[file.uri.pathSegments.last];
      final touched =
          _lastRead[object?.key] ?? object?.touched ?? stat.modified;
      final lastUse = touched.isAfter(stat.modified) ? touched : stat.modified;
      bytes += stat.size;
      entries.add((file: file, key: object?.key, used: lastUse, stat: stat));
    }
    if (bytes <= diskBudget) return;
    entries.sort((a, b) => a.used.compareTo(b.used));
    for (final entry in entries) {
      if (bytes <= diskBudget || _pendingImages > 0) break;
      if (now.difference(entry.used) < _idle) break;
      final current = await entry.file.stat();
      if (current.modified != entry.stat.modified ||
          current.size != entry.stat.size) {
        continue;
      }
      if (entry.key case final key?) {
        await removeFile(key);
        _lastRead.remove(key);
      }
      await _deleteCacheFile(entry.file);
      bytes -= current.size;
    }
    if (bytes > diskBudget) scheduleTrim();
  }

  Future<void> clearDisk() => _runMaintenance(() async {
        final files = await _diskFiles().toList();
        await emptyCache();
        // Older cache entries can have a relative path or no index entry.
        for (final file in files) {
          await _deleteCacheFile(file);
        }
        _lastRead.clear();
      });

  Future<void> _deleteCacheFile(File file) async {
    try {
      await file.delete();
    } on PathNotFoundException {
      // The cache manager can also have removed this file.
    }
  }
}

class StorageSnapshot {
  final int media;
  final int updates;
  final int exports;
  final int drafts;
  const StorageSnapshot(this.media, this.updates, this.exports, this.drafts);
}

class AppStorage {
  static Future<Directory> updateDirectory() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/app_update');

  static Future<void> reclaimInstalledUpdate() async {
    if (!Platform.isAndroid) return;
    try {
      await const MethodChannel('lovegirl/device')
          .invokeMethod<bool>('reclaimInstalledUpdate');
    } on PlatformException catch (error) {
      LogService().error('Storage', '已安装更新包清理失败: ${error.code}');
    } on MissingPluginException {
      return;
    }
  }

  static Future<StorageSnapshot> read(int? account) async {
    final temp = await getTemporaryDirectory();
    final docs = await getApplicationDocumentsDirectory();
    final exports = await _exportFolders(temp).toList();
    final sizes = await Future.wait([
      _size(await MediaCache.instance.directory()),
      Future.wait([
        _size(File('${temp.path}/$updateApkName')),
        _size(File('${temp.path}/$updateApkName.part')),
        _size(await updateDirectory()),
      ]).then((values) => values.fold<int>(0, (sum, n) => sum + n)),
      Future.wait(exports.map(_size))
          .then((values) => values.fold<int>(0, (sum, n) => sum + n)),
      if (account != null)
        _size(Directory('${docs.path}/creation_drafts/$account'))
      else
        Future.value(0),
    ]);
    return StorageSnapshot(sizes[0], sizes[1], sizes[2], sizes[3]);
  }

  static Future<void> clearMediaAndExpiredExports() async {
    await MediaCache.instance.clearDisk();
    final temp = await getTemporaryDirectory();
    await for (final directory in _exportFolders(temp)) {
      final stat = await directory.stat();
      if (DateTime.now().difference(stat.modified) > const Duration(hours: 1)) {
        await directory.delete(recursive: true);
      }
    }
  }

  static Stream<Directory> _exportFolders(Directory temp) => temp
      .list(followLinks: false)
      .where((entry) =>
          entry is Directory && _basename(entry).startsWith('lovegirl_export_'))
      .cast<Directory>();

  static String _basename(FileSystemEntity entry) =>
      entry.path.split(Platform.pathSeparator).last;

  static Future<int> _size(FileSystemEntity entry) async {
    final stat = await entry.stat();
    if (stat.type == FileSystemEntityType.file) return stat.size;
    if (stat.type != FileSystemEntityType.directory || entry is! Directory) {
      return 0;
    }
    var bytes = 0;
    await for (final item in entry.list(recursive: true, followLinks: false)) {
      if (item is File) bytes += (await item.stat()).size;
    }
    return bytes;
  }
}
