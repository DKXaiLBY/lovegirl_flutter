import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'creation_catalog.dart';
import 'creation_document.dart';

/// The same artwork is painted on screen and into the exported PNG.
class CreationPainter extends CustomPainter {
  final CreationDocument document;
  final List<ui.Image> images;
  final bool back;
  final CreationInk? activeInk;
  final bool includeInk;
  const CreationPainter(this.document, this.images,
      {this.back = false, this.activeInk, this.includeInk = true});

  static List<Rect> photoWindows(CreationDocument d) {
    const w = 880.0;
    final h = w / d.aspectRatio;
    if (d.kind != 'ticket') {
      final material = d.paper.material;
      final inset = switch (material) {
        PaperMaterial.film => 85.0,
        PaperMaterial.archive => 74.0,
        PaperMaterial.carbon => 70.0,
        PaperMaterial.peelBlack => 50.0,
        _ => 48.0,
      };
      final top = switch (material) {
        PaperMaterial.archive => 100.0,
        PaperMaterial.carbon => 70.0,
        PaperMaterial.peelBlack => 52.0,
        _ => 48.0,
      };
      return [Rect.fromLTWH(inset, top, w - inset * 2, w - inset * 2)];
    }
    return switch (d.templateId) {
      'landscape' => [Rect.fromLTWH(30, 30, 410, h - 60)],
      'portrait' => [Rect.fromLTWH(48, 110, w - 96, h * .48)],
      'postcard' => [Rect.fromLTWH(32, 32, w - 64, h * .62)],
      'filmstrip' => [
          Rect.fromLTWH(85, 90, 710, h * .34),
          Rect.fromLTWH(85, h * .34 + 115, 710, h * .34)
        ],
      'couple' => [
          Rect.fromLTWH(30, 30, 395, h * .58),
          Rect.fromLTWH(455, 30, 395, h * .58)
        ],
      'datestamp' => [Rect.fromLTWH(45, h * .26, 790, h * .49)],
      'boarding' => [Rect.fromLTWH(30, 70, 290, h - 100)],
      'route' => [Rect.fromLTWH(40, 110, 800, h * .42)],
      _ => [Rect.fromLTWH(32, 32, 816, h * .6)]
    };
  }

  @override
  void paint(Canvas canvas, Size size) {
    final h = 880 / document.aspectRatio;
    canvas.save();
    canvas.scale(size.width / 880, size.height / h);
    final rect = Rect.fromLTWH(0, 0, 880, h);
    final path = outline(document, rect);
    canvas.drawShadow(path, Colors.black.withAlpha(70), 10, false);
    canvas.save();
    canvas.clipPath(path);
    final paper = document.kind == 'ticket'
        ? (document.templateId == 'filmstrip'
            ? const Color(0xff24262b)
            : document.background)
        : document.paper.color;
    canvas.drawRect(rect, Paint()..color = paper);
    if (document.kind == 'ticket' && document.gradient) {
      canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              colors: [paper, Color.lerp(paper, document.accent, .32)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(rect));
    }
    _texture(canvas, rect);
    if (back) {
      _back(canvas, rect);
    } else {
      final windows = photoWindows(document);
      for (var i = 0; i < windows.length; i++) {
        _photo(canvas, windows[i], i);
      }
      if (document.kind == 'ticket') {
        _ticketDetails(canvas, rect, windows);
      } else {
        _paperDetails(canvas, rect);
      }
    }
    final strokes = includeInk
        ? (back ? document.backInk : document.frontInk)
        : <CreationInk>[];
    for (final stroke in [...strokes, if (activeInk != null) activeInk!]) {
      if (stroke.points.isEmpty) continue;
      final pen = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width * 880
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final points = stroke.points.map((p) => Offset(p.dx * 880, p.dy * h));
      if (stroke.points.length == 1) {
        canvas.drawCircle(
            points.first, pen.strokeWidth / 2, Paint()..color = stroke.color);
      } else {
        final line = Path()..moveTo(points.first.dx, points.first.dy);
        for (final p in points.skip(1)) {
          line.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(line, pen);
      }
    }
    canvas.restore();
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = Colors.black.withAlpha(24));
    // A sealed print has a fine lit lip, rather than a thick raised frame.
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
        path.shift(const Offset(0, 1.5)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white.withAlpha(145));
    canvas.drawPath(
        path.shift(const Offset(-1, -2)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.black.withAlpha(26));
    canvas.restore();
    canvas.restore();
  }

  static Path outline(CreationDocument d, Rect r) {
    if (d.kind == 'ticket') {
      final path = Path()
        ..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(12)));
      final holes = Path();
      final horizontal = d.aspectRatio > 1.7;
      // Small cut edges belong to the paper, not to a rectangular UI card.
      if (d.templateId != 'postcard' && d.templateId != 'filmstrip') {
        for (var y = 20.0; y < r.height - 12; y += 13) {
          holes.addOval(Rect.fromCircle(center: Offset(0, y), radius: 2));
          holes.addOval(Rect.fromCircle(center: Offset(r.width, y), radius: 2));
        }
      }
      if (horizontal) {
        holes.addOval(
            Rect.fromCircle(center: Offset(r.width * .77, 0), radius: 20));
        holes.addOval(Rect.fromCircle(
            center: Offset(r.width * .77, r.height), radius: 20));
      } else {
        holes.addOval(
            Rect.fromCircle(center: Offset(0, r.height - 80), radius: 22));
        holes.addOval(Rect.fromCircle(
            center: Offset(r.width, r.height - 80), radius: 22));
      }
      return Path.combine(PathOperation.difference, path, holes);
    }
    final m = d.paper.material;
    if (m == PaperMaterial.wave) {
      final p = Path()..moveTo(8, 8);
      for (var x = 8.0; x < r.width - 8; x += 32) {
        p.quadraticBezierTo(x + 8, 0, x + 16, 8);
        p.quadraticBezierTo(x + 24, 16, math.min(x + 32, r.width - 8), 8);
      }
      p.lineTo(r.width - 8, r.height - 8);
      for (var x = r.width - 8; x > 8; x -= 32) {
        p.quadraticBezierTo(x - 8, r.height, x - 16, r.height - 8);
        p.quadraticBezierTo(
            x - 24, r.height - 16, math.max(x - 32, 8), r.height - 8);
      }
      p.close();
      return p;
    }
    if (m == PaperMaterial.peelWhite || m == PaperMaterial.peelBlack) {
      final p = Path()..moveTo(0, 0);
      for (var x = 0.0; x < r.width; x += 16) {
        p.lineTo(x, (x ~/ 16).isEven ? 0 : 5);
      }
      p.lineTo(r.width, r.height);
      for (var x = r.width; x > 0; x -= 16) {
        p.lineTo(x, r.height - ((x ~/ 16).isEven ? 0 : 6));
      }
      p.close();
      return p;
    }
    final p = Path()..fillType = PathFillType.evenOdd;
    p.addRRect(RRect.fromRectAndRadius(r, const Radius.circular(5)));
    if (m == PaperMaterial.archive) {
      for (final x in [255.0, 625.0]) {
        p.addOval(Rect.fromCircle(center: Offset(x, 42), radius: 17));
      }
    }
    return p;
  }

  void _texture(Canvas c, Rect r) {
    final m = document.paper.material;
    final ticket = document.kind == 'ticket';
    final smooth = !ticket &&
        ![
          PaperMaterial.cotton,
          PaperMaterial.linen,
          PaperMaterial.fold,
          PaperMaterial.peelWhite,
          PaperMaterial.postmark
        ].contains(m);
    c.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: smooth
                  ? const [
                      Color(0x14ffffff),
                      Color(0x00ffffff),
                      Color(0x076b7480)
                    ]
                  : const [
                      Color(0x08ffffff),
                      Color(0x00ffffff),
                      Color(0x086b7480)
                    ],
              stops: const [0, .72, 1]).createShader(r));
    final random = math.Random(1409);
    final ink = Paint();
    for (var i = 0; i < 1800; i++) {
      ink.color = (i.isEven ? Colors.black : Colors.white).withAlpha(ticket
          ? 13
          : m == PaperMaterial.cotton
              ? 22
              : smooth
                  ? 3
                  : 9);
      c.drawCircle(
          Offset(random.nextDouble() * r.width, random.nextDouble() * r.height),
          m == PaperMaterial.cotton ? 1.7 : .8,
          ink);
    }
    if (ticket) {
      // Fine, short fibres remain restrained at phone scale.
      for (var i = 0; i < 600; i++) {
        final point = Offset(
            random.nextDouble() * r.width, random.nextDouble() * r.height);
        c.drawLine(
            point,
            point + Offset(1.5 + random.nextDouble() * 4, .8),
            Paint()
              ..color = const Color(0x0a454d56)
              ..strokeWidth = .6);
      }
      return;
    }
    if (m == PaperMaterial.linen) {
      for (var x = 0.0; x < 880; x += 6) {
        c.drawLine(Offset(x, 0), Offset(x, r.height),
            Paint()..color = const Color(0x1481858e));
      }
      for (var y = 0.0; y < r.height; y += 7) {
        c.drawLine(Offset(0, y), Offset(880, y),
            Paint()..color = const Color(0x149ca0a6));
      }
    }
    if ([
      PaperMaterial.pearl,
      PaperMaterial.silver,
      PaperMaterial.clear,
      PaperMaterial.frost
    ].contains(m)) {
      final metallic = m == PaperMaterial.silver;
      c.drawRect(
          r,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: metallic
                  ? const [
                      Color(0xffaeb4ba),
                      Color(0xfff1f3f5),
                      Color(0xffb4bac0),
                      Color(0xffe0e4e6)
                    ]
                  : const [
                      Color(0x10a8c8e8),
                      Color(0x99ffffff),
                      Color(0x208bb3c8)
                    ],
              stops: metallic ? const [0, .36, .6, 1] : null,
            ).createShader(r));
    }
    if (m == PaperMaterial.fold) {
      c.drawRect(
          Rect.fromLTWH(430, 0, 20, r.height),
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0x007e7e7e), Color(0x307e7e7e), Color(0x00ffffff)],
            ).createShader(Rect.fromLTWH(430, 0, 20, r.height)));
      c.drawLine(
          Offset(0, r.height * .58),
          Offset(880, r.height * .58),
          Paint()
            ..color = const Color(0x20717171)
            ..strokeWidth = 3);
    }
  }

  void _photo(Canvas c, Rect window, int index) {
    c.save();
    final rounded = RRect.fromRectAndRadius(
        window,
        Radius.circular(document.kind == 'polaroid' &&
                document.paper.material == PaperMaterial.frost
            ? 18
            : 0));
    c.clipRRect(rounded);
    if (index >= images.length) {
      c.drawRect(window, Paint()..color = const Color(0xffdce1e7));
      _text(c, '选择照片', window.deflate(20), 28, const Color(0xff657080),
          center: true);
    } else {
      final image = images[index];
      final crop = index < document.transforms.length
          ? document.transforms[index]
          : const CreationCrop();
      final fit =
          math.max(window.width / image.width, window.height / image.height) *
              crop.scale;
      final target = Rect.fromCenter(
        center: window.center +
            Offset(crop.x * (image.width * fit - window.width) / 2,
                crop.y * (image.height * fit - window.height) / 2),
        width: image.width * fit,
        height: image.height * fit,
      );
      final paint = Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter =
            ColorFilter.matrix(document.look.matrix(document.intensity));
      if (document.look.softness * document.intensity > 0) {
        paint.imageFilter = ui.ImageFilter.blur(
            sigmaX: document.look.softness * document.intensity * .7,
            sigmaY: document.look.softness * document.intensity * .7);
      }
      c.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          target,
          paint);
      paint.colorFilter = null;
      paint.imageFilter = null;
      final look = document.look;
      if (look.vignette > 0) {
        c.drawRect(
            window,
            Paint()
              ..shader = RadialGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withAlpha(
                      (look.vignette * document.intensity * 255).round())
                ],
                stops: const [.4, 1],
                radius: .85,
              ).createShader(window));
      }
      if (look.grain > 0 && document.intensity > 0) {
        final random = math.Random(79 + index);
        final dots = <Offset>[];
        for (var i = 0; i < 9000; i++) {
          dots.add(Offset(window.left + random.nextDouble() * window.width,
              window.top + random.nextDouble() * window.height));
        }
        c.drawPoints(
            ui.PointMode.points,
            dots,
            Paint()
              ..color = Colors.black.withAlpha(
                  (look.grain * document.intensity * 500).round().clamp(0, 100))
              ..strokeWidth = 1.7);
      }
    }
    if (document.kind != 'ticket' &&
        ![
          PaperMaterial.cotton,
          PaperMaterial.linen,
          PaperMaterial.frost,
          PaperMaterial.fold
        ].contains(document.paper.material)) {
      c.drawRect(
          window,
          Paint()
            ..shader = const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0x00ffffff),
                  Color(0x04ffffff),
                  Color(0x24ffffff),
                  Color(0x02ffffff),
                  Color(0x00ffffff)
                ],
                stops: [
                  0,
                  .3,
                  .52,
                  .66,
                  1
                ]).createShader(window));
    }
    // The image sits nearly flush under the protective surface.
    c.drawRect(
        window,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x260c1723), Color(0x000c1723)],
              stops: [0, .008]).createShader(window));
    c.restore();
    c.drawRRect(
        rounded,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.black.withAlpha(36));
  }

  void _paperDetails(Canvas c, Rect r) {
    final m = document.paper.material;
    final color = document.paper.ink;
    final h = r.height;
    if (m == PaperMaterial.carbon) {
      final photo = photoWindows(document).first;
      for (final corner in [
        photo.topLeft,
        photo.topRight,
        photo.bottomLeft,
        photo.bottomRight
      ]) {
        final dx = corner.dx == photo.left ? 1.0 : -1.0;
        final dy = corner.dy == photo.top ? 1.0 : -1.0;
        final mount = Path()
          ..moveTo(corner.dx, corner.dy)
          ..lineTo(corner.dx + dx * 52, corner.dy)
          ..lineTo(corner.dx, corner.dy + dy * 52)
          ..close();
        c.drawPath(mount, Paint()..color = const Color(0xff17191c));
        c.drawLine(
            corner + Offset(dx * 52, 0),
            corner + Offset(0, dy * 52),
            Paint()
              ..color = const Color(0x559ca0a8)
              ..strokeWidth = 1.5);
      }
      for (final y in [1034.0, 1042.0]) {
        c.drawLine(Offset(60, y), Offset(820, y),
            Paint()..color = const Color(0x30868b95));
      }
    }
    if (m == PaperMaterial.pearl) {
      final seal = Rect.fromCircle(center: const Offset(791, 980), radius: 20);
      c.drawOval(
          seal,
          Paint()
            ..shader =
                const RadialGradient(colors: [Colors.white, Color(0xffcecbdc)])
                    .createShader(seal));
      c.drawOval(
          seal.deflate(3),
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0x99ffffff));
    }
    if (m == PaperMaterial.peelBlack) {
      c.drawRect(const Rect.fromLTWH(50, 1030, 780, 22),
          Paint()..color = const Color(0xffd3d5d6));
      for (var x = 665.0; x < 815; x += 8) {
        c.drawLine(
            Offset(x, 1033),
            Offset(x, 1049),
            Paint()
              ..color = const Color(0xff636970)
              ..strokeWidth = 2);
      }
    }
    if (m == PaperMaterial.blueSplit) {
      c.drawRect(
          Rect.fromLTWH(0, 0, 25, h), Paint()..color = const Color(0xff738fae));
      c.drawRect(Rect.fromLTWH(0, h - 30, 880, 30),
          Paint()..color = const Color(0xffa7bbcf));
    }
    if (m == PaperMaterial.sageEdge || m == PaperMaterial.clear) {
      for (final inset in [17.0, 24.0]) {
        c.drawRect(
            r.deflate(inset),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = m == PaperMaterial.clear
                  ? Colors.white
                  : const Color(0xff8a9a88));
      }
    }
    if (m == PaperMaterial.roseCorner) {
      final fold = Path()
        ..moveTo(806, h)
        ..lineTo(880, h - 74)
        ..lineTo(880, h)
        ..close();
      c.drawPath(fold, Paint()..color = const Color(0xffd8bac3));
      c.drawLine(
          Offset(806, h),
          Offset(880, h - 74),
          Paint()
            ..color = const Color(0xffb899a5)
            ..strokeWidth = 2);
    }
    if (m == PaperMaterial.film) {
      for (var y = 75.0; y < 760; y += 58) {
        for (final x in [18.0, 832.0]) {
          c.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromLTWH(x, y, 30, 34), const Radius.circular(5)),
              Paint()..color = const Color(0xffdadbd9));
        }
      }
      _text(c, 'FILM FRAME  /  TWO OF US', Rect.fromLTWH(80, 780, 700, 35), 16,
          const Color(0xffb8babc));
    }
    if (m == PaperMaterial.letter) {
      for (var y = 850.0; y < h - 30; y += 45) {
        c.drawLine(Offset(38, y), Offset(842, y),
            Paint()..color = const Color(0x209197a5));
      }
      c.drawRect(
          Rect.fromLTWH(50, 987, 80, 27),
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0xff9c646c));
      _text(c, 'DATE', const Rect.fromLTWH(60, 989, 65, 25), 15,
          const Color(0xff9c646c));
    }
    if (m == PaperMaterial.tape) {
      c.save();
      c.translate(440, 35);
      c.rotate(-.045);
      c.drawRect(const Rect.fromLTWH(-145, -30, 290, 65),
          Paint()..color = const Color(0xbbc3c8cf));
      c.restore();
    }
    if (m == PaperMaterial.postmark) {
      c.save();
      c.translate(738, 915);
      c.rotate(-.15);
      c.drawCircle(
          Offset.zero,
          66,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xff78828d));
      c.drawCircle(
          Offset.zero,
          59,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0xff78828d));
      _text(c, 'OUR TRIP\nMEMORY', const Rect.fromLTWH(-48, -25, 96, 60), 15,
          const Color(0xff78828d),
          center: true);
      c.restore();
    }
    _text(
        c,
        document.title,
        Rect.fromLTWH(55, 865, m == PaperMaterial.postmark ? 590 : 770, 85),
        43,
        color,
        handwritten: true);
    _text(
        c,
        (document.date ?? '').replaceAll('-', '.'),
        Rect.fromLTWH(m == PaperMaterial.letter ? 150 : 58, h - 88, 650, 40),
        26,
        color.withAlpha(190),
        handwritten: true);
  }

  void _ticketDetails(Canvas c, Rect r, List<Rect> windows) {
    final d = document;
    final h = r.height;
    final dark = d.templateId == 'filmstrip';
    final color = dark ? Colors.white : const Color(0xff22252b);
    final horizontal = d.aspectRatio > 1.7;
    Rect title;
    Rect note;
    if (horizontal) {
      final left = d.templateId == 'boarding' ? 350.0 : 470.0;
      title = Rect.fromLTWH(left, 75, 670 - left - 24, h * .3);
      note = Rect.fromLTWH(left, h * .47, 670 - left - 24, h * .25);
      _dash(c, Offset(880 * .77, 20), Offset(880 * .77, h - 20), d.accent);
    } else if (d.templateId == 'datestamp') {
      title = Rect.fromLTWH(50, 65, 780, 130);
      note = Rect.fromLTWH(50, h * .81, 780, h * .11);
      _text(c, d.date ?? '', Rect.fromLTWH(50, h * .18, 780, 70), 48, d.accent);
    } else {
      final top = windows.last.bottom + 35;
      title = Rect.fromLTWH(45, top, 790, h * .1);
      note = Rect.fromLTWH(45, top + h * .1, 790, h - top - h * .1 - 100);
      _dash(c, Offset(25, h - 80), Offset(855, h - 80), d.accent);
    }
    _text(c, d.title.isEmpty ? '我们的纪念' : d.title, title, horizontal ? 34 : 43,
        color);
    _text(c, d.note, note, horizontal ? 18 : 25, color.withAlpha(180));
    _text(
        c,
        d.date ?? 'TWO OF US',
        Rect.fromLTWH(
            horizontal ? (d.templateId == 'boarding' ? 350 : 470) : 45,
            h - 52,
            horizontal ? 190 : 630,
            30),
        18,
        color.withAlpha(160));
    if (d.templateId == 'route') {
      final y = h * .90;
      c.drawLine(
          Offset(80, y),
          Offset(790, y),
          Paint()
            ..color = d.accent
            ..strokeWidth = 4);
      for (var i = 0; i < 4; i++) {
        c.drawCircle(Offset(80 + i * 237, y), 10, Paint()..color = d.accent);
      }
    } else {
      final random = math.Random(47);
      for (var x = 725.0; x < 828; x += 4) {
        c.drawRect(Rect.fromLTWH(x, h - 54, random.nextBool() ? 1 : 2, 28),
            Paint()..color = color);
      }
    }
    if (dark) {
      for (var y = 30.0; y < h; y += 58) {
        for (final x in [20.0, 832.0]) {
          c.drawRect(Rect.fromLTWH(x, y, 28, 32),
              Paint()..color = const Color(0xffd9dce0));
        }
      }
    }
  }

  void _back(Canvas c, Rect r) {
    final ink = document.kind == 'ticket'
        ? (document.templateId == 'filmstrip'
            ? Colors.white
            : const Color(0xff25282e))
        : document.paper.ink;
    for (var y = 190.0; y < r.height - 60; y += 62) {
      c.drawLine(
          Offset(60, y), Offset(820, y), Paint()..color = ink.withAlpha(25));
    }
    _text(c, 'TO US', const Rect.fromLTWH(60, 65, 760, 50), 25,
        ink.withAlpha(150));
    _text(
        c, document.note, Rect.fromLTWH(60, 140, 760, r.height - 250), 34, ink,
        handwritten: true);
    _text(c, document.date ?? '', Rect.fromLTWH(60, r.height - 80, 760, 35), 23,
        ink.withAlpha(150));
  }

  void _dash(Canvas c, Offset a, Offset b, Color color) {
    final length = (b - a).distance;
    for (var t = 0.0; t < length; t += 15) {
      c.drawLine(
          a + (b - a) * (t / length),
          a + (b - a) * (math.min(t + 7, length) / length),
          Paint()
            ..color = color.withAlpha(110)
            ..strokeWidth = 2);
    }
  }

  void _text(Canvas c, String text, Rect rect, double fontSize, Color color,
      {bool center = false, bool handwritten = false}) {
    if (text.isEmpty || rect.height <= 0 || rect.width <= 0) return;
    final painter = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontFamily: handwritten ? 'Caveat' : null,
              height: 1.3,
              fontWeight: handwritten ? FontWeight.w500 : FontWeight.w600)),
      textAlign: center ? TextAlign.center : TextAlign.left,
      textDirection: TextDirection.ltr,
      ellipsis: '…',
      maxLines: math.max(1, (rect.height / (fontSize * 1.3)).floor()),
    )..layout(maxWidth: rect.width);
    c.save();
    c.clipRect(rect);
    painter.paint(
        c,
        Offset(rect.left,
            center ? rect.center.dy - painter.height / 2 : rect.top));
    c.restore();
    painter.dispose();
  }

  @override
  bool shouldRepaint(CreationPainter oldDelegate) =>
      oldDelegate.document.kind != document.kind ||
      oldDelegate.document.templateId != document.templateId ||
      oldDelegate.document.lookId != document.lookId ||
      oldDelegate.document.intensity != document.intensity ||
      oldDelegate.document.title != document.title ||
      oldDelegate.document.note != document.note ||
      oldDelegate.document.date != document.date ||
      oldDelegate.document.background != document.background ||
      oldDelegate.document.accent != document.accent ||
      oldDelegate.document.gradient != document.gradient ||
      oldDelegate.document.transforms != document.transforms ||
      oldDelegate.includeInk != includeInk ||
      (includeInk &&
          (oldDelegate.document.frontInk != document.frontInk ||
              oldDelegate.document.backInk != document.backInk)) ||
      oldDelegate.images != images ||
      oldDelegate.back != back ||
      oldDelegate.activeInk != activeInk;
}

class CreationArtwork extends StatelessWidget {
  final CreationDocument document;
  final List<ui.Image> images;
  final bool back;
  final CreationInk? activeInk;
  const CreationArtwork(
      {super.key,
      required this.document,
      required this.images,
      this.back = false,
      this.activeInk});
  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        RepaintBoundary(
            child: CustomPaint(
                painter: CreationPainter(document, images,
                    back: back, includeInk: false))),
        CustomPaint(
            painter: _InkPainter(document,
                back ? document.backInk : document.frontInk, activeInk)),
      ]);
}

class _InkPainter extends CustomPainter {
  final CreationDocument document;
  final List<CreationInk> strokes;
  final CreationInk? active;
  const _InkPainter(this.document, this.strokes, this.active);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final path = CreationPainter.outline(
        document, Rect.fromLTWH(0, 0, 880, 880 / document.aspectRatio));
    canvas.clipPath(path.transform((Matrix4.identity()
          ..scale(size.width / 880, size.height / (880 / document.aspectRatio)))
        .storage));
    for (final s in [...strokes, if (active != null) active!]) {
      if (s.points.isEmpty) continue;
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = s.width * size.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final points =
          s.points.map((p) => Offset(p.dx * size.width, p.dy * size.height));
      if (s.points.length == 1) {
        canvas.drawCircle(
            points.first, paint.strokeWidth / 2, Paint()..color = s.color);
      } else {
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (final p in points.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InkPainter oldDelegate) =>
      oldDelegate.strokes != strokes ||
      oldDelegate.active != active ||
      oldDelegate.document.templateId != document.templateId;
}

Future<Uint8List> renderCreation(
    CreationDocument document, List<ui.Image> images,
    {bool back = false, int width = 1760}) async {
  final recorder = ui.PictureRecorder();
  final size = Size(width.toDouble(), width / document.aspectRatio);
  CreationPainter(document, images, back: back).paint(Canvas(recorder), size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, size.height.round());
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('图片生成失败');
    return bytes.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}
