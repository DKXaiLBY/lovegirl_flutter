import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovegirl_flutter/features/creations/creation_catalog.dart';
import 'package:lovegirl_flutter/features/creations/creation_document.dart';
import 'package:lovegirl_flutter/features/creations/creation_drafts.dart';

void main() {
  late Directory root;
  setUp(() async =>
      root = await Directory.systemTemp.createTemp('lovegirl_draft_test_'));
  tearDown(() async {
    expect(root.absolute.path.startsWith(Directory.systemTemp.absolute.path),
        isTrue);
    await root.delete(recursive: true);
  });
  const document = CreationDocument(
      title: '海边，和你',
      note: '背面的故事',
      date: '2026-10-24',
      frontInk: [
        CreationInk(points: [Offset(.1, .85), Offset(.8, .92)])
      ],
      transforms: [
        CreationCrop(scale: 1.6, x: -.2, y: .1)
      ]);

  test('editable ink, crop, date and text survive serialization', () {
    final restored =
        CreationDocument.fromJson(jsonDecode(jsonEncode(document.toJson())));
    expect(restored.toJson(), document.toJson());
    expect(restored.frontInk.first.points.last.dy, .92);
    expect(creationArgb(restored.frontInk.first.color), 0xff202126);
  });

  test('draft owns its source after the picker temporary file disappears',
      () async {
    final source = File('${root.path}/picker.jpg');
    await source.writeAsBytes([1, 2, 3, 4]);
    final store = CreationDrafts(33, root: root);
    final draft = await store.create(document, [source.path],
        tripId: 7, tripTitle: '青岛两日');
    await source.delete();
    final reopened = await CreationDrafts(33, root: root).list();
    expect(reopened.single.id, draft.id);
    expect(await File(reopened.single.sourcePaths.single).readAsBytes(),
        [1, 2, 3, 4]);
    expect(reopened.single.tripId, 7);
    expect(reopened.single.document.toJson(), document.toJson());
  });

  test(
      'autosaves serialize and the latest version reopens after a new store instance',
      () async {
    final source = await File('${root.path}/source.jpg').writeAsBytes([1]);
    final store = CreationDrafts(33, root: root);
    final draft = await store.create(document, [source.path]);
    await Future.wait(List.generate(
        20,
        (index) => store.save(
            draft.copyWith(document: document.copyWith(title: '修改 $index')))));
    expect((await CreationDrafts(33, root: root).list()).single.document.title,
        '修改 19');
  });

  test('different accounts cannot read or overwrite each other drafts',
      () async {
    final source = await File('${root.path}/source.jpg').writeAsBytes([1]);
    final own = CreationDrafts(33, root: root);
    final draft = await own.create(document, [source.path]);
    final other = CreationDrafts(32, root: root);
    expect(await other.list(), isEmpty);
    await expectLater(other.save(draft), throwsStateError);
    expect((await own.list()).single.document.title, document.title);
  });

  test('invalid ids never address files outside an account directory',
      () async {
    final store = CreationDrafts(33, root: root);
    await expectLater(store.delete('../../outside'), throwsFormatException);
    expect(await root.exists(), isTrue);
  });

  test('one damaged draft is reported without hiding the valid drafts',
      () async {
    final source = await File('${root.path}/source.jpg').writeAsBytes([1]);
    final store = CreationDrafts(33, root: root);
    await store.create(document, [source.path]);
    final damaged = await store.directory('damaged_draft');
    await damaged.create();
    await File('${damaged.path}/draft.json').writeAsString('{broken');
    expect((await store.list()).length, 1);
    expect(store.unreadable.length, 1);
  });

  test('deleting waits for pending saves and does not resurrect the draft',
      () async {
    final source = await File('${root.path}/source.jpg').writeAsBytes([1]);
    final store = CreationDrafts(33, root: root);
    final draft = await store.create(document, [source.path]);
    final saving =
        store.save(draft.copyWith(document: document.copyWith(title: '新内容')));
    await store.delete(draft.id);
    await saving;
    expect(await store.list(), isEmpty);
  });

  test('catalog has twenty paper materials, eight layouts and twelve looks',
      () {
    expect(paperTemplates.map((value) => value.id).toSet().length, 20);
    expect(paperTemplates.map((value) => value.material).toSet().length, 20);
    expect(ticketTemplates.map((value) => value.id).toSet().length, 8);
    expect(creationLooks.map((value) => value.id).toSet().length, 12);
  });

  test(
      'zero strength is original and black-white presets have equal RGB output',
      () {
    for (final look in creationLooks) {
      final matrix = look.matrix(0);
      expect(matrix[0], 1);
      expect(matrix[6], 1);
      expect(matrix[12], 1);
      expect(matrix[18], 1);
      expect(matrix[4], 0);
    }
    for (final look in creationLooks.where((look) => look.family == '黑白')) {
      final matrix = look.matrix(1);
      double channel(int row) =>
          matrix[row * 5] * 50 +
          matrix[row * 5 + 1] * 120 +
          matrix[row * 5 + 2] * 200 +
          matrix[row * 5 + 4];
      expect(channel(0), closeTo(channel(1), .0001));
      expect(channel(1), closeTo(channel(2), .0001));
    }
  });
}
