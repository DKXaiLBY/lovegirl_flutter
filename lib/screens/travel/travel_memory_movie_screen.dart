import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../providers/travel_provider.dart';
import '../../utils/constants.dart';

/// 回忆电影（W6，复刻 map-for-love 的"电影感时光轨迹"交互——
/// 该项目无 LICENSE，仅参考交互规格，Flutter 全部自研实现）：
/// 三阶段状态机 sequence（逐城点亮+拍立得气泡）→ draw（渐变连线画出）→ done（定格）。
/// 数据：已打卡点按 visitedDate 升序（travel_spots 自带 photos）。
class TravelMemoryMovieScreen extends StatefulWidget {
  final List<TravelSpot> spots;

  const TravelMemoryMovieScreen({super.key, required this.spots});

  @override
  State<TravelMemoryMovieScreen> createState() =>
      _TravelMemoryMovieScreenState();
}

class _MoviePoint {
  final TravelSpot spot;
  final Offset pos; // 画布坐标
  final String dateText;
  _MoviePoint(this.spot, this.pos, this.dateText);
}

enum _MoviePhase { intro, sequence, draw, done }

const Color _lineRose = Color(0xFFE8B8C2);
const Color _lineBlue = Color(0xFFA8C8DC);
const Color _bgNight = Color(0xFF171A21);

class _TravelMemoryMovieScreenState extends State<TravelMemoryMovieScreen>
    with SingleTickerProviderStateMixin {

  late final List<_MoviePoint> _points;
  late final AnimationController _drawCtrl = AnimationController(
      vsync: this, duration: Duration(milliseconds: 400 * _points.length));
  int _activeIndex = -1;
  _MoviePhase _phase = _MoviePhase.intro;
  Timer? _timer;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    final visited = widget.spots
        .where((s) =>
            s.status == 'visited' &&
            (s.visitedDate ?? '').isNotEmpty &&
            s.lat <= 90 &&
            s.lat >= -90 &&
            s.lng <= 180 &&
            s.lng >= -180)
        .toList()
      ..sort((a, b) => (a.visitedDate ?? '')
          .compareTo(b.visitedDate ?? ''));
    _points = visited.map((s) {
      final d = DateTime.tryParse(s.visitedDate ?? '') ?? DateTime.now();
      return _MoviePoint(
          s, Offset.zero, '${d.year}.${d.month}.${d.day}');
    }).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _points.length >= 2) _startShow();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _drawCtrl.dispose();
    super.dispose();
  }

  void _startShow() {
    setState(() {
      _playing = true;
      _phase = _MoviePhase.sequence;
      _activeIndex = -1;
    });
    var current = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 1800), (t) {
      if (!mounted) return t.cancel();
      if (current < _points.length) {
        setState(() {
          _activeIndex = current;
          current++;
        });
      } else {
        t.cancel();
        setState(() {
          _phase = _MoviePhase.draw;
          _activeIndex = _points.length - 1;
        });
        _drawCtrl.forward(from: 0).whenComplete(() {
          if (mounted) setState(() => _phase = _MoviePhase.done);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgNight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            onPressed: () => Navigator.pop(context)),
        title: Text('我们的时光轨迹',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white.withAlpha(230))),
        actions: [
          if (!_playing && _points.length >= 2)
            IconButton(
                tooltip: '重播',
                icon: const Icon(Icons.replay_rounded, color: Colors.white70),
                onPressed: _startShow),
        ],
      ),
      body: _points.length < 2
          ? const Center(
              child: Text('至少需要 2 个已打卡的地点才能播放时光轨迹',
                  style: TextStyle(color: Colors.white54)))
          : LayoutBuilder(builder: (context, box) {
              final size = Size(box.maxWidth, box.maxHeight);
              final projected = _projectAll(size);
              return Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                        animation: Listenable.merge([_drawCtrl]),
                        builder: (context, _) => CustomPaint(
                              painter: _MoviePainter(
                                points: projected,
                                phase: _phase,
                                drawProgress: _phase == _MoviePhase.draw
                                    ? _drawCtrl.value
                                    : (_phase == _MoviePhase.done
                                        ? 1.0
                                        : 0.0),
                                activeIndex: _activeIndex,
                              ),
                            )),
                  ),
                  // 拍立得气泡层（sequence 当前城 + done 全部定格）
                  ..._bubbles(projected, size),
                  if (_phase == _MoviePhase.sequence)
                    const Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                          child: Text('回想我们一起走过的日子…',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 12))),
                    ),
                ],
              );
            }),
    );
  }

  List<_MoviePoint> _projectAll(Size canvas) {
    if (_points.isEmpty) return _points;
    double minX = 180, maxX = -180, minY = 90, maxY = -90;
    final merc = _points.map((p) {
      // Web 墨卡托 y 归一化（等距线性在中国南北跨度下会压扁）
      final rad = p.spot.lat * math.pi / 180;
      final y = math.log(math.tan(math.pi / 4 + rad / 2)) * 180 / math.pi;
      minX = math.min(minX, p.spot.lng);
      maxX = math.max(maxX, p.spot.lng);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
      return MapEntry(p, Offset(p.spot.lng, y));
    }).toList();
    final spanX = (maxX - minX).abs().clamp(0.5, 360.0);
    final spanY = (maxY - minY).abs().clamp(0.5, 180.0);
    final pad = 72.0;
    final availW = math.max(1.0, canvas.width - pad * 2);
    final availH = math.max(1.0, canvas.height - pad * 2);
    final scale = math.min(availW / spanX, availH / spanY);
    return merc.map((e) {
      final dx = (e.value.dx - minX) * scale;
      final dy = (maxY - e.value.dy) * scale;
      // 归一到 avail 区域再居中
      final cx = pad + (availW - (maxX - minX) * scale) / 2 + dx;
      final cy = pad + (availH - (maxY - minY) * scale) / 2 + dy;
      return _MoviePoint(e.key.spot, Offset(cx, cy), e.key.dateText);
    }).toList();
  }

  List<Widget> _bubbles(List<_MoviePoint> projected, Size size) {
    final widgets = <Widget>[];
    for (var i = 0; i < projected.length; i++) {
      final p = projected[i];
      final showNow = (_phase == _MoviePhase.sequence && i == _activeIndex) ||
          (_phase == _MoviePhase.done);
      final photo = p.spot.photos.isNotEmpty ? p.spot.photos.first : null;
      if (!showNow || photo == null && p.spot.coverImage == null) {
        // 无照片的城市点：sequence 时显示城市名标签
        if ((_phase == _MoviePhase.sequence && i == _activeIndex) ||
            _phase == _MoviePhase.done) {
          widgets.add(Positioned(
            left: p.pos.dx - 40,
            top: p.pos.dy + 10,
            width: 80,
            child: Text(p.spot.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70)),
          ));
        }
        continue;
      }
      final url = (photo ?? p.spot.coverImage)!;
      final tilt = i.isEven ? -0.06 : 0.06;
      widgets.add(Positioned(
        left: (p.pos.dx - 55).clamp(6.0, size.width - 116),
        top: (p.pos.dy - 130).clamp(8.0, size.height - 150),
        width: 110,
        height: 128,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 480),
          curve: Curves.easeOutBack,
          builder: (context, t, child) => Opacity(
            opacity: t.clamp(0, 1),
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - t)),
              child: Transform.rotate(angle: tilt * t, child: child),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(5, 5, 5, 18),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBF7),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white24),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x385A6670),
                    blurRadius: 24,
                    offset: Offset(0, 12)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: url.startsWith('http')
                    ? url
                    : '${AppConstants.baseUrl}$url',
                fit: BoxFit.cover,
                memCacheWidth: 300,
                errorWidget: (_, __, ___) =>
                    ColoredBox(color: Colors.black12),
              ),
            ),
          ),
        ),
      ));
    }
    return widgets;
  }
}

class _MoviePainter extends CustomPainter {
  final List<_MoviePoint> points;
  final _MoviePhase phase;
  final double drawProgress;
  final int activeIndex;

  _MoviePainter({
    required this.points,
    required this.phase,
    required this.drawProgress,
    required this.activeIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final projected = _offsets(size);
    final path = Path()..moveTo(projected.first.dx, projected.first.dy);
    for (final p in projected.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }

    // 底部阴影线（sequence 阶段隐藏）
    if (phase != _MoviePhase.sequence) {
      final shadow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = _lineRose.withAlpha(38);
      canvas.drawPath(path, shadow);
    }

    // 主渐变连线：draw 阶段按进度截断"画出"，done 全显
    if (phase == _MoviePhase.draw || phase == _MoviePhase.done) {
      final metric = path.computeMetrics().first;
      final target = metric.length * (phase == _MoviePhase.done ? 1 : drawProgress);
      final partial = metric.extractPath(0, target);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          colors: [_lineRose, _lineBlue, _lineRose],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(partial, paint);
    }

    // 城市点
    for (var i = 0; i < projected.length; i++) {
      final active =
          phase == _MoviePhase.done || i <= activeIndex;
      final isCurrent = i == activeIndex && phase == _MoviePhase.sequence;
      final r = isCurrent ? 6.0 : 4.0;
      final fill = active || phase != _MoviePhase.sequence
          ? _lineRose
          : const Color(0xFFD8DDD8);
      if (active && phase == _MoviePhase.sequence) {
        canvas.drawCircle(
            projected[i], 12, Paint()..color = _lineRose.withAlpha(38));
      }
      canvas.drawCircle(
          projected[i],
          r,
          Paint()
            ..color = fill
            ..style = PaintingStyle.fill);
      canvas.drawCircle(
          projected[i],
          r,
          Paint()
            ..color = const Color(0xFFFAFBF7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  List<Offset> _offsets(Size size) {
    if (points.isEmpty) return const [];
    double minX = 180, maxX = -180, minY = 90, maxY = -90;
    final merc = points.map((p) {
      final rad = p.spot.lat * math.pi / 180;
      final y = math.log(math.tan(math.pi / 4 + rad / 2)) * 180 / math.pi;
      minX = math.min(minX, p.spot.lng);
      maxX = math.max(maxX, p.spot.lng);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
      return Offset(p.spot.lng, y);
    }).toList();
    final spanX = (maxX - minX).abs().clamp(0.5, 360.0);
    final spanY = (maxY - minY).abs().clamp(0.5, 180.0);
    final pad = 72.0;
    final availW = math.max(1.0, size.width - pad * 2);
    final availH = math.max(1.0, size.height - pad * 2);
    final scale = math.min(availW / spanX, availH / spanY);
    final offX = pad + (availW - (maxX - minX) * scale) / 2;
    final offY = pad + (availH - (maxY - minY) * scale) / 2;
    return merc
        .map((e) => Offset(
            offX + (e.dx - minX) * scale, offY + (maxY - e.dy) * scale))
        .toList();
  }

  @override
  bool shouldRepaint(covariant _MoviePainter old) =>
      old.phase != phase ||
      old.drawProgress != drawProgress ||
      old.activeIndex != activeIndex ||
      old.points != points;
}
