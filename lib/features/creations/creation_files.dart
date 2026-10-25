import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../utils/constants.dart';
import 'creation_document.dart';
import 'creation_drafts.dart';

String creationUrl(String path) =>
    path.startsWith('http') ? path : '${AppConstants.baseUrl}$path';

Future<List<ui.Image>> decodeCreationImages(List<String> paths) async {
  final images = <ui.Image>[];
  try {
    for (final path in paths) {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes,
          targetWidth: 1800, allowUpscaling: false);
      try {
        images.add((await codec.getNextFrame()).image);
      } finally {
        codec.dispose();
      }
    }
    return images;
  } catch (_) {
    for (final image in images) {
      image.dispose();
    }
    rethrow;
  }
}

Future<CreationDraft> draftFromRemote(
    CreationDrafts store, CreationDocument document, List<String> urls,
    {int? workId, int? revision, int? tripId, String? tripTitle}) async {
  final temporary = await Directory((await getTemporaryDirectory()).path)
      .createTemp('creation_import_');
  try {
    final files = <String>[];
    for (var i = 0; i < urls.length; i++) {
      final uri = Uri.parse(creationUrl(urls[i]));
      // Only fetch our own media while creating an editable local copy.
      if (uri.host != Uri.parse(AppConstants.baseUrl).host ||
          !uri.path.startsWith('/uploads/')) {
        throw const FormatException('照片来源不正确');
      }
      final path = '${temporary.path}/$i.jpg';
      await Dio().download(uri.toString(), path,
          options: Options(receiveTimeout: const Duration(seconds: 30)));
      files.add(path);
    }
    return await store.create(document, files,
        workId: workId,
        revision: revision,
        tripId: tripId,
        tripTitle: tripTitle);
  } finally {
    await temporary.delete(recursive: true);
  }
}
