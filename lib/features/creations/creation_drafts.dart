import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'creation_document.dart';

/// Private, account-partitioned drafts. Nothing is uploaded until publishing.
class CreationDrafts {
  final int ownerId;
  final Directory? root;
  final List<String> unreadable = [];
  Future<void> _writes = Future.value();
  CreationDrafts(this.ownerId, {this.root});

  Future<Directory> _account() async {
    if (ownerId <= 0) throw StateError('请先登录');
    final base = root ??
        Directory(
            '${(await getApplicationDocumentsDirectory()).path}/creation_drafts');
    return Directory('${base.path}/$ownerId').create(recursive: true);
  }

  Future<Directory> directory(String id) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{8,80}$').hasMatch(id)) {
      throw const FormatException('草稿标识不正确');
    }
    return Directory('${(await _account()).path}/$id');
  }

  Future<CreationDraft> create(CreationDocument document, List<String> sources,
      {int? workId, int? revision, int? tripId, String? tripTitle}) async {
    final id = const Uuid().v4();
    final folder = await directory(id);
    await folder.create(recursive: true);
    final paths = <String>[];
    try {
      for (var index = 0; index < sources.length; index++) {
        final target = '${folder.path}/source_$index.jpg';
        await File(sources[index]).copy(target);
        paths.add(target);
      }
      final draft = CreationDraft(
          id: id,
          ownerId: ownerId,
          document: document,
          sourcePaths: paths,
          workId: workId,
          revision: revision,
          tripId: tripId,
          tripTitle: tripTitle,
          updatedAt: DateTime.now());
      await save(draft);
      return draft;
    } catch (_) {
      await folder.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> save(CreationDraft draft) {
    final operation =
        _writes.catchError((Object _) {}).then((_) => _write(draft));
    _writes = operation;
    return operation;
  }

  Future<CreationDraft> replaceSource(
      CreationDraft draft, int index, String path) async {
    if (draft.ownerId != ownerId) throw StateError('不能修改其他账号的草稿');
    if (index < 0 || index >= draft.sourcePaths.length) {
      throw RangeError.index(index, draft.sourcePaths);
    }
    final folder = await directory(draft.id);
    final target = File('${folder.path}/source_${const Uuid().v4()}.jpg');
    try {
      await File(path).copy(target.path);
      final paths = [...draft.sourcePaths]..[index] = target.path;
      final transforms = List.generate(
          paths.length,
          (i) => i == index || i >= draft.document.transforms.length
              ? const CreationCrop()
              : draft.document.transforms[i]);
      final next = draft.copyWith(
          sourcePaths: paths,
          sourcesChanged: true,
          document: draft.document.copyWith(transforms: transforms));
      await save(next);
      // Superseded source copies live only until this private draft is removed.
      return next;
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    }
  }

  Future<void> _write(CreationDraft draft) async {
    if (draft.ownerId != ownerId) throw StateError('不能保存其他账号的草稿');
    final folder = await directory(draft.id);
    await folder.create(recursive: true);
    final temporary = File('${folder.path}/draft.next');
    await temporary.writeAsString(jsonEncode(draft.toJson()), flush: true);
    await temporary.rename('${folder.path}/draft.json');
  }

  Future<List<CreationDraft>> list({String? kind}) async {
    unreadable.clear();
    final drafts = <CreationDraft>[];
    await for (final entity in (await _account()).list(followLinks: false)) {
      if (entity is! Directory) continue;
      final file = File('${entity.path}/draft.json');
      if (!await file.exists()) continue;
      try {
        final data = jsonDecode(await file.readAsString());
        final draft = CreationDraft.fromJson(Map<String, dynamic>.from(data));
        if (draft.ownerId != ownerId) {
          unreadable.add(entity.path);
          continue;
        }
        if (kind == null || draft.document.kind == kind) drafts.add(draft);
      } on FormatException {
        unreadable.add(entity.path);
      } on TypeError {
        unreadable.add(entity.path);
      }
    }
    drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return drafts;
  }

  Future<void> delete(String id) async {
    await _writes.catchError((Object _) {});
    final folder = await directory(id);
    if (await folder.exists()) await folder.delete(recursive: true);
  }
}
