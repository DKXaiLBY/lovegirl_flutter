import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'app_storage.dart';

class UpdatePackage {
  const UpdatePackage(
      {required this.code, required this.url, required this.size, this.md5});

  final int code;
  final Uri url;
  final int size;
  final String? md5;

  static UpdatePackage fromVersion(Map<String, dynamic> version, Uri origin) {
    final path = version['url']?.toString().trim() ?? '';
    final url = origin.resolve(path);
    final code = int.tryParse('${version['code']}') ?? 0;
    final size = int.tryParse('${version['size']}') ?? 0;
    if (path.isEmpty ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        (url.scheme != 'http' && url.scheme != 'https') ||
        code <= 0 ||
        size <= 0) {
      throw const FormatException('更新信息不完整');
    }
    final digest = version['md5']?.toString().trim().toLowerCase();
    return UpdatePackage(
        code: code,
        url: url,
        size: size,
        md5: digest != null && RegExp(r'^[a-f0-9]{32}$').hasMatch(digest)
            ? digest
            : null);
  }
}

class UpdateProgress {
  const UpdateProgress(this.bytes, {this.complete = false});
  final int bytes;
  final bool complete;
}

class UpdateDownloadException implements Exception {
  const UpdateDownloadException(this.message);
  final String message;
}

class UpdateDownload {
  UpdateDownload(this._directory);

  static final instance = UpdateDownload(AppStorage.updateDirectory);
  static final _range = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$');
  final Future<Directory> Function() _directory;
  bool _running = false;

  Future<UpdateProgress> progress(UpdatePackage package) async {
    final files = _UpdateFiles(await _directory());
    final identity = await files.identity(package);
    if (identity == null) return const UpdateProgress(0);
    if (await files.apk.exists() && await files.apk.length() == package.size) {
      return UpdateProgress(package.size, complete: true);
    }
    return UpdateProgress(await files.offset(package, identity));
  }

  Future<File> download(UpdatePackage package, CancelToken cancel,
      void Function(int) onProgress) async {
    if (_running) throw const UpdateDownloadException('已有更新任务，稍后继续');
    _running = true;
    final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 35),
        responseType: ResponseType.stream,
        validateStatus: (_) => true));
    try {
      final directory = await _directory();
      await directory.create(recursive: true);
      final files = _UpdateFiles(directory);
      final saved = await files.identity(package);
      if (saved != null &&
          await files.apk.exists() &&
          await files.apk.length() == package.size) {
        if (await _verified(files.apk, package)) {
          onProgress(package.size);
          return files.apk;
        }
        await files.apk.delete();
      }
      var received = saved == null ? 0 : await files.offset(package, saved);
      onProgress(received);
      if (received != package.size) {
        final initialOffset = received;
        var response = await _request(dio, package, cancel, received, saved);
        if (received > 0 &&
            response.statusCode != 200 &&
            (response.statusCode == 416 ||
                response.statusCode == 206 &&
                    !_matchesRange(response, received, package, saved!))) {
          await response.data?.stream.listen(null).cancel();
          response = await _request(dio, package, cancel, 0, null);
          received = 0;
        }
        final full = response.statusCode == 200;
        final length =
            int.tryParse(response.headers.value('content-length') ?? '');
        final encoding = response.headers.value('content-encoding');
        final body = response.data;
        if (body == null ||
            (encoding != null && encoding != 'identity') ||
            (full
                ? length != null && length != package.size
                : received == 0 ||
                    !_matchesRange(response, received, package, saved!))) {
          throw const UpdateDownloadException('服务器返回的更新文件不一致，请重新检查更新');
        }
        if (cancel.isCancelled) throw cancel.cancelError!;
        if (full) {
          received = 0;
          if (await files.apk.exists()) await files.apk.delete();
        }
        final writer = await files.part
            .open(mode: full ? FileMode.write : FileMode.append);
        try {
          if (full) {
            await files.writeIdentity(_UpdateIdentity(
                package,
                response.headers.value('etag'),
                response.headers.value('last-modified')));
            if (initialOffset > 0) onProgress(0);
          }
          await for (final chunk in body.stream) {
            if (cancel.isCancelled) throw cancel.cancelError!;
            if (received + chunk.length > package.size) {
              await writer.truncate(full ? 0 : initialOffset);
              throw const UpdateDownloadException('更新文件超出预期大小，请重试');
            }
            await writer.writeFrom(chunk);
            received += chunk.length;
            onProgress(received);
          }
        } finally {
          try {
            await writer.flush();
          } finally {
            await writer.close();
          }
        }
      }
      if (cancel.isCancelled) throw cancel.cancelError!;
      if (received != package.size) {
        throw const UpdateDownloadException('下载中断，可以继续下载');
      }
      if (!await _verified(files.part, package)) {
        await files.part.delete();
        throw const UpdateDownloadException('安装包校验失败，请重新下载');
      }
      return files.part.rename(files.apk.path);
    } finally {
      dio.close(force: true);
      _running = false;
    }
  }

  Future<Response<ResponseBody>> _request(Dio dio, UpdatePackage package,
      CancelToken cancel, int offset, _UpdateIdentity? saved) {
    final validator = saved?.validator;
    return dio.getUri<ResponseBody>(package.url,
        cancelToken: cancel,
        options: Options(headers: {
          'Accept-Encoding': 'identity',
          if (offset > 0) 'Range': 'bytes=$offset-',
          if (offset > 0 && validator != null) 'If-Range': validator,
        }));
  }

  bool _matchesRange(Response<ResponseBody> response, int offset,
      UpdatePackage package, _UpdateIdentity saved) {
    if (response.statusCode != 206) return false;
    final match =
        _range.firstMatch(response.headers.value('content-range') ?? '');
    if (match == null ||
        int.tryParse(match[1]!) != offset ||
        int.tryParse(match[3]!) != package.size) {
      return false;
    }
    final end = int.tryParse(match[2]!);
    final length = int.tryParse(response.headers.value('content-length') ?? '');
    final tag = response.headers.value('etag');
    final date = response.headers.value('last-modified');
    return end != null &&
        end >= offset &&
        end < package.size &&
        (length == null || length == end - offset + 1) &&
        (saved.tag == null || tag == null || saved.tag == tag) &&
        (saved.modified == null || date == null || saved.modified == date);
  }

  Future<bool> _verified(File file, UpdatePackage package) async {
    if (await file.length() != package.size) return false;
    final expected = package.md5;
    return expected == null ||
        (await md5.bind(file.openRead()).first).toString() == expected;
  }
}

class _UpdateFiles {
  _UpdateFiles(Directory directory)
      : apk = File('${directory.path}/$updateApkName'),
        part = File('${directory.path}/$updateApkName.part'),
        state = File('${directory.path}/download.json');

  final File apk, part, state;

  Future<_UpdateIdentity?> identity(UpdatePackage package) async {
    try {
      if (!await state.exists()) return null;
      final value = jsonDecode(await state.readAsString());
      if (value is! Map<String, dynamic> ||
          value['code'] != package.code ||
          value['size'] != package.size ||
          value['url'] != package.url.toString() ||
          value['md5'] != package.md5) {
        return null;
      }
      return _UpdateIdentity(
          package, value['etag'] as String?, value['date'] as String?);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<int> offset(UpdatePackage package, _UpdateIdentity identity) async {
    if ((identity.validator == null && package.md5 == null) ||
        !await part.exists()) {
      return 0;
    }
    final bytes = await part.length();
    return bytes <= package.size ? bytes : 0;
  }

  Future<void> writeIdentity(_UpdateIdentity identity) async {
    final pending = File('${state.path}.tmp');
    await pending.writeAsString(
        jsonEncode({
          'code': identity.package.code,
          'url': identity.package.url.toString(),
          'size': identity.package.size,
          'md5': identity.package.md5,
          'etag': identity.tag,
          'date': identity.modified,
        }),
        flush: true);
    await pending.rename(state.path);
  }
}

class _UpdateIdentity {
  const _UpdateIdentity(this.package, this.tag, this.modified);
  final UpdatePackage package;
  final String? tag, modified;

  // HTTP If-Range rejects weak ETags. The server's Last-Modified lets
  // clients resume even when its ETag is weak.
  String? get validator => tag?.startsWith('"') == true ? tag : modified;
}
