import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovegirl_flutter/services/update_download.dart';

void main() {
  final payload = Uint8List.fromList(List.generate(128 * 1024, (i) => i % 251));
  const prefix = 24 * 1024;
  const modified = 'Tue, 24 Nov 2026 13:36:22 GMT';
  late Directory directory;
  late HttpServer server;
  late UpdateDownload download;
  late UpdatePackage package;
  late List<(String?, String?)> requests;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('lovegirl-update-test-');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    download = UpdateDownload(() async => directory);
    package = UpdatePackage(
      code: 198,
      url: Uri.parse('http://127.0.0.1:${server.port}/release.apk'),
      size: payload.length,
      md5: md5.convert(payload).toString(),
    );
    requests = [];
  });

  tearDown(() async {
    await server.close(force: true);
    await directory.delete(recursive: true);
  });

  void serve(
      {bool ignoreRange = false,
      bool wrongRange = false,
      bool disconnect = false,
      bool corrupt = false}) {
    server.listen((request) async {
      final range = request.headers.value('range');
      requests.add((range, request.headers.value('if-range')));
      final response = request.response;
      response.headers.set('etag', 'W/"test"');
      response.headers.set('last-modified', modified);
      final start = range != null && !ignoreRange
          ? int.parse(range.substring(6, range.length - 1)) +
              (wrongRange ? 1 : 0)
          : 0;
      if (start > 0) {
        response.statusCode = HttpStatus.partialContent;
        response.headers.set(
          'content-range',
          'bytes $start-${payload.length - 1}/${payload.length}',
        );
      }
      response.contentLength = payload.length - start;
      if (requests.length == 1 && disconnect) {
        final socket = await response.detachSocket(writeHeaders: true);
        socket.add(payload.sublist(0, prefix));
        await socket.flush();
        await socket.close();
        return;
      }
      if (requests.length == 1 && !corrupt) {
        response.add(payload.sublist(0, prefix));
        await response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 80));
        response.add(payload.sublist(prefix));
      } else {
        final body = payload.sublist(start);
        if (corrupt) body[0] ^= 1;
        response.add(body);
      }
      await response.close();
    });
  }

  Future<int> pauseDownload() async {
    final token = CancelToken();
    await expectLater(
      download.download(package, token, (bytes) {
        if (bytes >= prefix) token.cancel();
      }),
      throwsA(isA<DioException>()),
    );
    final saved = await download.progress(package);
    expect(saved.bytes, prefix);
    expect(saved.complete, isFalse);
    return saved.bytes;
  }

  test('pause and reopen restores bytes, requests a range, and verifies APK',
      () async {
    serve();
    final saved = await pauseDownload();
    final reopened = UpdateDownload(() async => directory);
    expect((await reopened.progress(package)).bytes, saved);
    final apk = await reopened.download(package, CancelToken(), (_) {});
    expect(await apk.readAsBytes(), payload);
    expect(requests, [(null, null), ('bytes=$saved-', modified)]);
    expect((await reopened.progress(package)).complete, isTrue);
    await reopened.download(package, CancelToken(), (_) {});
    expect(requests, hasLength(2));
  });

  test('interrupted response retains downloaded bytes for retry', () async {
    serve(disconnect: true);
    await expectLater(
      download.download(package, CancelToken(), (_) {}),
      throwsA(isA<HttpException>()),
    );
    final saved = (await download.progress(package)).bytes;
    expect(saved, prefix);
    final file = await download.download(package, CancelToken(), (_) {});
    expect(await file.readAsBytes(), payload);
    expect(requests.last, ('bytes=$saved-', modified));
  });

  test('full response to a range replaces the partial file', () async {
    serve(ignoreRange: true);
    final saved = await pauseDownload();
    final file = await download.download(package, CancelToken(), (_) {});
    expect(await file.readAsBytes(), payload);
    expect(requests.last, ('bytes=$saved-', modified));
  });

  test('incorrect content range is discarded before a full retry', () async {
    serve(wrongRange: true);
    final saved = await pauseDownload();
    final file = await download.download(package, CancelToken(), (_) {});
    expect(await file.readAsBytes(), payload);
    expect(requests, [(null, null), ('bytes=$saved-', modified), (null, null)]);
  });

  test('a new package version starts at zero with the same download URL',
      () async {
    serve();
    await pauseDownload();
    final newer = UpdatePackage(
      code: package.code + 1,
      url: package.url,
      size: package.size,
      md5: package.md5,
    );
    expect((await download.progress(newer)).bytes, 0);
    final file = await download.download(newer, CancelToken(), (_) {});
    expect(await file.readAsBytes(), payload);
    expect(requests, [(null, null), (null, null)]);
  });

  test('checksum mismatch prevents installation and clears corrupted bytes',
      () async {
    serve(corrupt: true);
    await expectLater(
      download.download(package, CancelToken(), (_) {}),
      throwsA(isA<UpdateDownloadException>()),
    );
    expect((await download.progress(package)).bytes, 0);
    expect(
        directory.listSync().map((entry) => entry.path),
        everyElement(
          isNot(endsWith('.apk')),
        ));
  });
}
