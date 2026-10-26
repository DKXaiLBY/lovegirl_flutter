import 'dart:io';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovegirl_flutter/features/creations/creation_canvas.dart';
import 'package:lovegirl_flutter/features/creations/creation_document.dart';
import 'package:lovegirl_flutter/features/creations/creation_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ui.Image fixture;
  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
        const Rect.fromLTWH(0, 0, 600, 500),
        Paint()
          ..shader = const LinearGradient(
                  colors: [Color(0xff8ac5df), Color(0xfff1d7bd)])
              .createShader(const Rect.fromLTWH(0, 0, 600, 500)));
    for (var i = 0; i < 6; i++) {
      canvas.drawCircle(
          Offset(100.0 + i * 85, 120.0 + (i % 2) * 100),
          65,
          Paint()
            ..color = [
              Colors.red,
              Colors.green,
              Colors.blue,
              Colors.yellow,
              Colors.purple,
              Colors.white
            ][i]);
    }
    canvas.drawRect(
        const Rect.fromLTWH(70, 330, 150, 120), Paint()..color = Colors.black);
    final picture = recorder.endRecording();
    fixture = await picture.toImage(600, 500);
    picture.dispose();
  });
  tearDownAll(() => fixture.dispose());

  test('painting preserves the caller canvas transform and clipping stack', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..translate(23, 41)
      ..save();
    final transform = canvas.getTransform().toList();
    final count = canvas.getSaveCount();
    for (final d in [
      ...paperTemplates.map((p) => CreationDocument(
          templateId: p.id, title: 'Title', note: 'Story', date: '2026-10-25')),
      ...ticketTemplates.map((t) => CreationDocument(
          kind: 'ticket',
          templateId: t.id,
          title: 'Title',
          note: 'Story',
          date: '2026-10-25')),
    ]) {
      for (final back in [false, true]) {
        CreationPainter(d, [fixture, fixture], back: back)
            .paint(canvas, Size(330, 330 / d.aspectRatio));
        expect(canvas.getSaveCount(), count,
            reason: '${d.templateId} back=$back');
        expect(canvas.getTransform().toList(), transform,
            reason: '${d.templateId} back=$back');
      }
    }
    canvas.restore();
    recorder.endRecording().dispose();
  });

  test('20 papers, 8 layouts and 12 looks produce distinct actual artwork',
      () async {
    final root = Platform.environment['LOVEGIRL_RENDER_OUTPUT'];
    final groups = <String, List<CreationDocument>>{
      'paper': paperTemplates
          .map((p) => CreationDocument(
              templateId: p.id, title: 'Our memory', date: '2026-10-25'))
          .toList(),
      'ticket': ticketTemplates
          .map((t) => CreationDocument(
              kind: 'ticket',
              templateId: t.id,
              title: 'Our memory',
              note: '一起经过的地方\nOur journey together',
              date: '2026-10-25',
              transforms:
                  List.generate(t.minimumPhotos, (_) => const CreationCrop())))
          .toList(),
      'look': creationLooks
          .map((l) => CreationDocument(lookId: l.id, title: 'Our memory'))
          .toList(),
    };
    for (final entry in groups.entries) {
      final hashes = <String>{};
      for (final d in entry.value) {
        final bytes = await renderCreation(d, [fixture, fixture], width: 440);
        hashes.add(sha256.convert(bytes).toString());
        if (root != null) {
          await Directory(root).create(recursive: true);
          await File(
                  '$root/${entry.key}_${d.kind == 'ticket' ? d.templateId : entry.key == 'look' ? d.lookId : d.templateId}.png')
              .writeAsBytes(bytes);
        }
      }
      expect(hashes.length, entry.value.length,
          reason: '${entry.key} should have no duplicate renders');
    }
  });

  test(
      'paper ink covers margins and backside separately; background survives export',
      () async {
    const d = CreationDocument(frontInk: [
      CreationInk(
          points: [Offset(.02, .02), Offset(.15, .02)],
          color: Colors.red,
          width: .02)
    ]);
    final front = await renderCreation(d, [fixture], width: 440);
    final back = await renderCreation(d, [fixture], width: 440, back: true);
    final codec = await ui.instantiateImageCodec(front);
    final image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final index = (11 * image.width + 30) * 4;
    expect(data!.getUint8(index), greaterThan(180));
    expect(data.getUint8(index + 1), lessThan(120));
    expect(sha256.convert(front), isNot(sha256.convert(back)));
    image.dispose();
    codec.dispose();
    const ticket = CreationDocument(kind: 'ticket', templateId: 'landscape');
    expect(
        sha256.convert(await renderCreation(ticket, [fixture], width: 440)),
        isNot(sha256.convert(await renderCreation(
            ticket.copyWith(background: Colors.blue, gradient: true), [fixture],
            width: 440))));
  });
  test('dark paper and film ticket backs keep their story text light',
      () async {
    for (final document in const [
      CreationDocument(templateId: 'carbon', note: 'Our story'),
      CreationDocument(
          kind: 'ticket', templateId: 'filmstrip', note: 'Our story')
    ]) {
      final bytes = await renderCreation(document, [], back: true, width: 440);
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      final pixels =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      var light = 0;
      for (var y = 30; y < 100; y++) {
        for (var x = 25; x < 300; x++) {
          final offset = (y * image.width + x) * 4;
          if (pixels.getUint8(offset) > 150 &&
              pixels.getUint8(offset + 1) > 150) {
            light++;
          }
        }
      }
      expect(light, greaterThan(100), reason: document.templateId);
      image.dispose();
      codec.dispose();
    }
  });
  test('ticket perforations cut into the paper without drawing outer discs',
      () async {
    const d = CreationDocument(kind: 'ticket', templateId: 'couple');
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..translate(32, 32);
    final height = 880 / d.aspectRatio;
    CreationPainter(d, [fixture, fixture]).paint(canvas, Size(880, height));
    final picture = recorder.endRecording();
    final image = await picture.toImage(944, (height + 64).ceil());
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final index = (((32 + height - 80).round() * image.width) + 24) * 4;
    expect(bytes.getUint8(index + 3), lessThan(128));
    image.dispose();
    picture.dispose();
  });
  test(
      'all instant paper photo windows stay square inside their physical margins',
      () {
    for (final paper in paperTemplates) {
      final window =
          CreationPainter.photoWindows(CreationDocument(templateId: paper.id))
              .single;
      expect(window.width, window.height, reason: paper.id);
      expect(window.bottom, lessThan(865), reason: paper.id);
    }
  });
}
