import 'dart:async';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../utils/lovegirl_theme.dart';

/// 照片主色提取：降采样统计，返回适合做票根深色背景的基色
class PhotoPalette {
  PhotoPalette._();

  static final Map<String, Color> _cache = {};

  static Future<Color> extract(NetworkImage image) async {
    final key = image.url;
    final cached = _cache[key];
    if (cached != null) return cached;
    try {
      final stream =
          image.resolve(const ImageConfiguration(devicePixelRatio: 1));
      final completer = Completer<ui.Image>();
      late ImageStreamListener listener;
      listener = ImageStreamListener((info, _) {
        completer.complete(info.image);
        stream.removeListener(listener);
      }, onError: (_, __) {
        if (!completer.isCompleted) completer.completeError('load failed');
      });
      stream.addListener(listener);
      final decoded = await completer.future.timeout(const Duration(seconds: 4));
      final bytes = await decoded.toByteData(format: ui.ImageByteFormat.rawRgba);
      decoded.dispose();
      if (bytes == null) return _fallback;
      final data = bytes.buffer.asUint32List();
      var r = 0, g = 0, b = 0, n = 0;
      for (var i = 0; i < data.length; i++) {
        r += (data[i] >> 0) & 0xFF;
        g += (data[i] >> 8) & 0xFF;
        b += (data[i] >> 16) & 0xFF;
        n++;
      }
      if (n == 0) return _fallback;
      final base = Color.fromARGB(255, r ~/ n, g ~/ n, b ~/ n);
      // 压暗压饱和，保证票根文字可读
      final hsl = HSLColor.fromColor(base);
      final dark = hsl
          .withSaturation((hsl.saturation * 0.75).clamp(0.25, 0.72))
          .withLightness((hsl.lightness * 0.42).clamp(0.12, 0.34))
          .toColor();
      _cache[key] = dark;
      return dark;
    } catch (_) {
      return _fallback;
    }
  }

  static const Color _fallback = Color(0xFF2C3A47);
}

/// 撕票线：虚线 + 两端半圆缺口
class TicketNotchLine extends StatelessWidget {
  final Axis axis;
  final Color color;

  const TicketNotchLine({
    super.key,
    this.axis = Axis.horizontal,
    this.color = LoveGirlTheme.separator,
  });

  @override
  Widget build(BuildContext context) {
    final notch = Container(
      width: axis == Axis.horizontal ? 18 : 10,
      height: axis == Axis.horizontal ? 10 : 18,
      color: const Color(0xFFFFFCF8),
    );
    final line = axis == Axis.horizontal
        ? SizedBox(
            height: 1,
            child: CustomPaint(painter: _DashPainter(color: color)),
          )
        : SizedBox(
            width: 1,
            child: CustomPaint(painter: _DashPainter(color: color, vertical: true)),
          );
    if (axis == Axis.horizontal) {
      return SizedBox(
        height: 10,
        child: Row(
          children: [
            Transform.translate(offset: const Offset(-9, 0), child: notch),
            Expanded(child: line),
            Transform.translate(offset: const Offset(9, 0), child: notch),
          ],
        ),
      );
    }
    return SizedBox(
      width: 10,
      child: Column(
        children: [
          Transform.translate(offset: const Offset(0, -9), child: notch),
          Expanded(child: line),
          Transform.translate(offset: const Offset(0, 9), child: notch),
        ],
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  final bool vertical;

  const _DashPainter({required this.color, this.vertical = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    const dash = 5.0;
    const gap = 4.0;
    final length = vertical ? size.height : size.width;
    var dist = 0.0;
    while (dist < length) {
      final next = (dist + dash).clamp(0.0, length);
      if (vertical) {
        canvas.drawLine(Offset(0, dist), Offset(0, next), paint);
      } else {
        canvas.drawLine(Offset(dist, 0), Offset(next, 0), paint);
      }
      dist = next + gap;
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => oldDelegate.color != color;
}

/// 横版入场券：左 60% 照片原样，右 40% 主色深底票根区（TRAVEL STUB/城市/感悟/编号）
class HorizontalTicketStub extends StatelessWidget {
  final String? photoUrl;
  final String city;
  final String quote;
  final String ticketNo;
  final String? date;

  const HorizontalTicketStub({
    super.key,
    required this.photoUrl,
    required this.city,
    required this.quote,
    required this.ticketNo,
    this.date,
  });

  @override
  Widget build(BuildContext context) {
    final image = photoUrl != null
        ? Image.network(photoUrl!, fit: BoxFit.cover, width: double.infinity,
            errorBuilder: (_, __, ___) => const SizedBox.expand())
        : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF8),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(30),
                blurRadius: 16,
                offset: const Offset(0, 8)),
          ],
        ),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 左 60%：照片完整保留
              Expanded(
                flex: 6,
                child: image ??
                    Container(
                        color: LoveGirlTheme.primarySoft,
                        child: const Center(
                          child: Icon(Icons.photo_outlined,
                              size: 40, color: LoveGirlTheme.primary),
                        ),
                      ),
              ),
              // 撕票线
              SizedBox(
                width: 10,
                child: TicketNotchLine(axis: Axis.vertical),
              ),
              // 右 40%：深色票根区（主色渐变）
              Expanded(
                flex: 4,
                child: FutureBuilder<Color>(
                  future: photoUrl == null
                      ? Future.value(PhotoPalette._fallback)
                      : PhotoPalette.extract(NetworkImage(photoUrl!)),
                  builder: (context, snap) {
                    final base = snap.data ?? const Color(0xFF2C3A47);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [base, Color.lerp(base, Colors.black, .35)!],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('TRAVEL STUB',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 8,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Expanded(
                            child: Text(
                              city,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  height: 1.15,
                                  fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (date != null && date!.isNotEmpty)
                            Text(date!,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 8)),
                          const SizedBox(height: 4),
                          Text(
                            quote,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 9, height: 1.3),
                          ),
                          const SizedBox(height: 4),
                          Text('NO.$ticketNo',
                              style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 8,
                                  letterSpacing: 1)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 竖版明信片：上 35% 米白文字区（TRAVEL MEMORY/城市/日期），下 65% 照片
class VerticalPostcardTicket extends StatelessWidget {
  final String? photoUrl;
  final String city;
  final String quote;
  final String? date;

  const VerticalPostcardTicket({
    super.key,
    required this.photoUrl,
    required this.city,
    required this.quote,
    this.date,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF8),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(30),
                blurRadius: 16,
                offset: const Offset(0, 8)),
          ],
        ),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 上 35%：文字区
              Expanded(
                flex: 35,
                child: Container(
                  color: const Color(0xFFF4F0E8),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TRAVEL MEMORY',
                          style: TextStyle(
                              color: LoveGirlTheme.textMuted,
                              fontSize: 9,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(
                        city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: LoveGirlTheme.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w900),
                      ),
                      if (quote.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(quote,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: LoveGirlTheme.textSecondary,
                                fontSize: 10)),
                      ],
                      if (date != null && date!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(date!,
                            style: const TextStyle(
                                color: LoveGirlTheme.textMuted,
                                fontSize: 9,
                                letterSpacing: 1)),
                      ],
                    ],
                  ),
                ),
              ),
              TicketNotchLine(axis: Axis.horizontal),
              // 下 65%：照片完整保留
              Expanded(
                flex: 65,
                child: photoUrl != null
                    ? Image.network(photoUrl!,
                        fit: BoxFit.cover, width: double.infinity,
                        errorBuilder: (_, __, ___) =>
                            Container(color: LoveGirlTheme.primarySoft))
                    : Container(
                        color: LoveGirlTheme.primarySoft,
                        child: const Center(
                          child: Icon(Icons.photo_outlined,
                              size: 44, color: LoveGirlTheme.primary),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
